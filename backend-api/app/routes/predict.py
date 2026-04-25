from fastapi import APIRouter, UploadFile, File, Form, Request, HTTPException
import base64
from io import BytesIO
from PIL import Image
from app.database.mongodb import get_database
from app.services.email_service import send_emergency_alert_email
from app.services.cloudinary_service import upload_complaint_image, is_cloudinary_enabled
from datetime import datetime, timezone
import uuid
import os
import math
import logging
import requests
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import inch
from fastapi.responses import FileResponse, RedirectResponse
from pydantic import BaseModel
from typing import Optional
from pymongo import ReturnDocument

# Custom Services and Data
from app.services.population_service import get_density
from app.data.final_weights import W1, W2, W3, W4, W5

router = APIRouter()
logger = logging.getLogger(__name__)

UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

EMERGENCY_STATUS_FLOW = ["Reported", "In Progress", "Help Arriving", "Resolved", "Closed"]
ADMIN_ALERT_EMAILS = [
    "rizwik475@gmail.com",
    "priyanshunerella@gmail.com",
    "mjahnavi956@gmail.com",
]

# --- UTILITY METHODS ---

def now_utc() -> datetime:
    return datetime.now(timezone.utc)

def get_priority_label(score: float) -> str:
    if score > 0.7:
        return "HIGH"
    elif score >= 0.4:
        return "MEDIUM"
    else:
        return "LOW"

# --- HYDERABAD WARD DATA ---
HYDERABAD_WARDS = [
    {"name": "Charminar Ward", "lat": 17.3616, "lng": 78.4747},
    {"name": "Banjara Hills Ward", "lat": 17.4156, "lng": 78.4350},
    {"name": "Jubilee Hills Ward", "lat": 17.4326, "lng": 78.4071},
    {"name": "Secunderabad Ward", "lat": 17.4399, "lng": 78.4983},
    {"name": "Hitech City Ward", "lat": 17.4504, "lng": 78.3808},
    {"name": "Gachibowli Ward", "lat": 17.4401, "lng": 78.3489},
    {"name": "Ameerpet Ward", "lat": 17.4375, "lng": 78.4482},
    {"name": "LB Nagar Ward", "lat": 17.3457, "lng": 78.5522},
    {"name": "Kukatpally Ward", "lat": 17.4948, "lng": 78.3996},
    {"name": "Financial District Ward", "lat": 17.4172, "lng": 78.3370},
    {"name": "Abids Ward", "lat": 17.3891, "lng": 78.4744},
]

DEPARTMENT_MAP = {
    "Pothole": "Road Maintenance & Engineering Department",
    "Road Crack": "Infrastructure & Pavement Department",
    "Garbage": "Sanitation & Solid Waste Management Department",
    "Flood / Leak": "Water Supply & Sewerage Board",
    "Fallen Tree": "Urban Forestry & Horticulture Department",
    "Live Wire": "Electrical Safety & Lighting Department",
    "Accident": "Emergency Response & Police Unit",
    "Fire": "Fire & Rescue Services",
    "SOS": "Rapid Emergency Response Command",
    "Other": "General Ward Administration"
}

def get_nearest_ward(lat, lng):
    nearest = HYDERABAD_WARDS[0]
    min_dist = float('inf')
    for ward in HYDERABAD_WARDS:
        dist = math.sqrt((lat - ward["lat"])**2 + (lng - ward["lng"])**2)
        if dist < min_dist:
            min_dist = dist
            nearest = ward
    return nearest["name"]

def get_department(category):
    return DEPARTMENT_MAP.get(category, "Municipal Administration Department")

def compute_priority(v, t, rho, category, confidence):
    """
    Computes priority score using 5 weights:
    v: upvotes, t: days since report, rho: population density,
    category: type of issue, confidence: AI model confidence.
    """
    if category.lower() == "no issue":
        return 0.0 if confidence < 0.8 else 0.2
        
    Vmax = 100
    rho_max = 10000
    lambda_ = 0.15

    # U(x) - Upvote/Time Decay
    U = min(1, v / Vmax) * math.exp(-lambda_ * t)

    # D(x) - Density factor
    D = min(1, rho / rho_max)

    # C(x) - Category Weight
    CATEGORY_WEIGHTS = {
        "Pothole": 0.9,
        "Road Crack": 0.85,
        "Garbage": 0.6,
    }
    C = CATEGORY_WEIGHTS.get(category, 0.5)

    # T(x) - Deadline Pressure
    DEADLINE_MAP = {
        "Pothole": 7,
        "Road Crack": 10,
        "Garbage": 2,
    }
    deadline_days = DEADLINE_MAP.get(category, 5)
    r = max(0, deadline_days - t)
    T = 1 - (r / deadline_days)

    # Confidence (normalized 0-1)
    conf = confidence

    # Final weighted score using global W1-W5 weights
    return W1 * U + W2 * D + W3 * C + W4 * conf + W5 * T

def get_location_details(latitude, longitude):
    try:
        url = "https://nominatim.openstreetmap.org/reverse"
        params = {"lat": latitude, "lon": longitude, "format": "json"}
        headers = {"User-Agent": "civic-monitor-app"}
        response = requests.get(url, params=params, headers=headers, timeout=5)
        data = response.json()
        address = data.get("address", {})

        suburb = address.get("suburb") or address.get("neighbourhood")
        city = address.get("city") or address.get("town") or address.get("village")
        state = address.get("state")
        
        parts = [suburb, city, state]
        location = ", ".join([p for p in parts if p])
        
        address_parts = {
            "suburb": suburb,
            "city": city,
            "state": state,
            "postcode": address.get("postcode"),
            "country": address.get("country"),
        }

        return (
            location if location else f"({latitude}, {longitude})",
            city or "Unknown",
            address_parts
        )
    except Exception:
        return f"({latitude}, {longitude})", "Unknown", {}

def get_relevant_authority(category):
    if category in ["Pothole", "Road Crack"]:
        return "GHMC", "Roads & Maintenance Department"
    if category == "Garbage":
        return "GHMC", "Sanitation & Waste Management Department"
    if category == "Broken Streetlight":
        return "GHMC", "Electrical & Street Lighting Wing"
    return "Municipal Corporation", "Public Works Department"

def generate_complaint_letter(complaint_id, category, lat, lng, loc_name, submitted_at, city_name="Unknown"):
    date_str = submitted_at.strftime("%d %B %Y")
    dept = get_department(category)
    
    # HYDERABAD SPECIFIC ROUTING (Including suburbs like Kokapet, Gachibowli)
    loc_lower = (loc_name or "").lower()
    city_lower = (city_name or "").lower()
    is_hyd = "hyderabad" in city_lower or "hyderabad" in loc_lower or "telangana" in loc_lower
    
    ward_info = ""
    if is_hyd:
        ward_name = get_nearest_ward(lat, lng)
        ward_info = f"\nTo: The Ward Officer\n{ward_name}, Hyderabad Region\nSubject: {dept}\n"
    else:
        ward_info = f"\nTo: The Municipal Commissioner\n{loc_name or 'City Administration'}\nSubject: {dept}\n"

    letter_text = f"""
CIVIC COMPLAINT REPORT
Complaint ID: {complaint_id}
Date: {date_str}
{ward_info}
--------------------------------------------------
Dear Authority,

This is a formal report regarding a {category} issue observed at {loc_name or 'the specified coordinates'}.

Location Details:
- Coordinates: {lat}, {lng}
- Description: {category} requiring immediate attention from the {dept}.

Our AI system has verified this issue and assigned it to the appropriate department for resolution.

Please take necessary action at the earliest.

Sincerely,
A Concerned Citizen (via CivicVision)
--------------------------------------------------
    """
    return letter_text.strip()

def generate_pdf_letter(complaint_id, letter_text):
    pdf_path = os.path.join(UPLOAD_FOLDER, f"{complaint_id}.pdf").replace('\\', '/')
    doc = SimpleDocTemplate(pdf_path, pagesize=A4)
    styles = getSampleStyleSheet()
    elements = [Paragraph(line, styles["Normal"]) for line in letter_text.split("\n")]
    doc.build(elements)
    return pdf_path

# --- REQUEST MODELS ---

class EmergencyReportRequest(BaseModel):
    image: str
    latitude: float
    longitude: float
    category: str
    short_text: Optional[str] = None
    reporter_email: Optional[str] = None

class SosRequest(BaseModel):
    latitude: float
    longitude: float
    note: Optional[str] = None
    reporter_email: Optional[str] = None

class UpvoteRequest(BaseModel):
    email: str

class AdminVerifyRequest(BaseModel):
    category: str

class StatusUpdate(BaseModel):
    status: str

# --- ENDPOINTS ---

@router.post("/predict")
async def predict(
    request: Request,
    image: str = Form(None),
    file: UploadFile = File(None),
    latitude: float = Form(None),
    longitude: float = Form(None),
    reporter_email: str = Form(None),
):
    complaint_id = str(uuid.uuid4())
    submitted_at = now_utc()

    if request.headers.get("content-type", "").startswith("application/json"):
        payload = await request.json()
        image, latitude, longitude, reporter_email = payload.get("image"), payload.get("latitude"), payload.get("longitude"), payload.get("reporter_email")

    if latitude is None or longitude is None:
        raise HTTPException(status_code=400, detail="Location required")

    file_path = os.path.join(UPLOAD_FOLDER, f"{complaint_id}.jpg").replace('\\', '/')
    if image:
        if "," in image: image = image.split(",", 1)[1]
        Image.open(BytesIO(base64.b64decode(image))).convert('RGB').save(file_path, "JPEG")
    elif file:
        with open(file_path, "wb") as b: b.write(await file.read())
    else:
        raise HTTPException(status_code=400, detail="Image required")

    image_url = None
    try:
        image_url = upload_complaint_image(file_path, complaint_id)
    except Exception as e:
        logger.error(f"Cloudinary failed: {e}")

    from app.model.model_loader import predict_image
    prediction = predict_image(file_path)
    category, confidence = prediction["category"], prediction["confidence"]
    
    loc_name, city_name, addr = get_location_details(latitude, longitude)
    rho = get_density(loc_name)
    priority_score = compute_priority(0, 0, rho, category, confidence)
    priority = get_priority_label(priority_score)

    # Get deadline days for frontend display
    DEADLINE_MAP = {"Pothole": 7, "Road Crack": 10, "Garbage": 2}
    deadline_days = DEADLINE_MAP.get(category, 5)

    letter_text, pdf_path = None, None
    if category.lower() == "no issue" and confidence > 0.75:
        status_val = "Rejected (Auto)"
    elif confidence < 0.75:
        status_val = "Needs Review"
        # Still generate a letter draft even for review
        letter_text = generate_complaint_letter(complaint_id, category, latitude, longitude, loc_name, submitted_at, city_name=city_name)
        pdf_path = generate_pdf_letter(complaint_id, letter_text)
    else:
        status_val = "Submitted"
        letter_text = generate_complaint_letter(complaint_id, category, latitude, longitude, loc_name, submitted_at, city_name=city_name)
        pdf_path = generate_pdf_letter(complaint_id, letter_text)

    db = get_database()
    db["complaints"].insert_one({
        "complaint_id": complaint_id, "category": category, "confidence": confidence,
        "priority": priority, "priority_score": priority_score, "latitude": latitude, "longitude": longitude,
        "city": city_name, "location_name": loc_name, "address": addr, "image_path": file_path, "image_url": image_url,
        "pdf_path": pdf_path, "letter": letter_text, "status": status_val, "upvotes": 0,
        "created_at": submitted_at.isoformat(), "reporter_email": (reporter_email or "").strip().lower()
    })

    return {
        "complaint": {
            "complaint_id": complaint_id,
            "category": category,
            "confidence": confidence,  # Added this!
            "status": status_val,
            "submitted_at": submitted_at.isoformat()
        },
        "location": {
            "latitude": latitude,
            "longitude": longitude,
            "city": city_name,
            "location_name": loc_name,
            "address": addr,
        },
        "pdf_download_url": f"/download/{complaint_id}",
        "letter": letter_text,
        "deadline_days": deadline_days,
        "message": "Complaint successfully registered"
    }

@router.get("/complaints")
def get_all_complaints(admin: bool = False, lat: float = None, lng: float = None, radius: float = 10.0):
    db = get_database()
    query = {"status": {"$ne": "Rejected (Auto)"}} if admin else {"status": {"$nin": ["Rejected", "Needs Review", "Rejected (No Issue)", "Rejected (Auto)"]}}
    complaints = list(db["complaints"].find(query, {"_id": 0}))

    if lat is not None and lng is not None:
        filtered = []
        for c in complaints:
            clat = c.get("latitude")
            clng = c.get("longitude")
            if clat and clng:
                # Basic distance calculation (approx 111km per degree)
                dist = math.sqrt((lat - clat)**2 + (lng - clng)**2) * 111
                if dist <= radius:
                    filtered.append(c)
        complaints = filtered

    for c in complaints:
        try:
            v, cat, conf_raw = c.get("upvotes", 0), c.get("category"), c.get("confidence", 0)
            
            # Robust confidence parsing
            if isinstance(conf_raw, str):
                conf = {"low": 0.25, "medium": 0.5, "high": 0.75, "critical": 1.0}.get(conf_raw.lower(), 0.5)
            else:
                conf = float(conf_raw or 0)
                
            # Robust date parsing
            raw_date = c.get("created_at")
            if isinstance(raw_date, str):
                created_at = datetime.fromisoformat(raw_date)
            elif isinstance(raw_date, datetime):
                created_at = raw_date
            else:
                created_at = now_utc()
                
            t = (now_utc() - created_at).days
            rho = get_density(c.get("location_name"))
            
            c["priority_score"] = compute_priority(v, t, rho, cat, conf)
            c["priority"] = get_priority_label(c["priority_score"])
        except Exception as e:
            logger.error(f"Error processing priority for complaint {c.get('complaint_id')}: {e}")
            c["priority_score"] = 0.0
            c["priority"] = "LOW"
    return complaints

@router.get("/complaints/my")
def get_my_complaints(email: str):
    db = get_database()
    return list(db["complaints"].find({"reporter_email": email.strip().lower(), "status": {"$ne": "Rejected (Auto)"}}, {"_id": 0}))

@router.get("/complaint/{complaint_id}")
def get_complaint(complaint_id: str):
    db = get_database()
    complaint = db["complaints"].find_one({"complaint_id": complaint_id}, {"_id": 0})
    if not complaint:
        raise HTTPException(status_code=404, detail="Complaint not found")
    return complaint

@router.post("/complaint/{complaint_id}/upvote")
def upvote_complaint(complaint_id: str, payload: UpvoteRequest):
    db = get_database()
    email = payload.email.strip().lower()
    if db["complaints"].find_one({"complaint_id": complaint_id, "upvoted_by": email}):
        raise HTTPException(status_code=400, detail="Already upvoted")

    result = db["complaints"].find_one_and_update(
        {"complaint_id": complaint_id}, {"$inc": {"upvotes": 1}, "$addToSet": {"upvoted_by": email}},
        return_document=ReturnDocument.AFTER
    )
    if not result: raise HTTPException(status_code=404, detail="Not found")

    # Robust date parsing
    raw_date = result.get("created_at")
    if isinstance(raw_date, str):
        created_at = datetime.fromisoformat(raw_date)
    elif isinstance(raw_date, datetime):
        created_at = raw_date
    else:
        created_at = now_utc()
        
    t = (now_utc() - created_at).days
    rho = get_density(result.get("location_name"))
    
    conf_raw = result.get("confidence", 0)
    if isinstance(conf_raw, str):
        conf = {"low": 0.25, "medium": 0.5, "high": 0.75, "critical": 1.0}.get(conf_raw.lower(), 0.5)
    else:
        conf = float(conf_raw or 0)
        
    new_score = compute_priority(result["upvotes"], t, rho, result["category"], conf)
    
    db["complaints"].update_one({"complaint_id": complaint_id}, {"$set": {"priority_score": new_score, "priority": get_priority_label(new_score)}})
    return {"success": True, "upvotes": result["upvotes"], "priority_score": new_score}

@router.get("/complaint/{complaint_id}/image")
def get_complaint_image(complaint_id: str):
    complaint = get_database()["complaints"].find_one({"complaint_id": complaint_id}, {"_id": 0, "image_path": 1, "image_url": 1})
    if not complaint: raise HTTPException(status_code=404)
    if complaint.get("image_url"): return RedirectResponse(url=complaint["image_url"])
    path = complaint.get("image_path", "").replace('\\', '/')
    if os.path.exists(path): return FileResponse(path, media_type="image/jpeg")
    raise HTTPException(status_code=404)

@router.get("/download/{complaint_id}")
def download_pdf(complaint_id: str):
    path = f"uploads/{complaint_id}.pdf"
    if os.path.exists(path): return FileResponse(path, media_type="application/pdf", filename=f"{complaint_id}.pdf")
    raise HTTPException(status_code=404)

@router.get("/admin/dashboard")
def admin_dashboard():
    db = get_database()
    return {
        "total_complaints": db["complaints"].count_documents({}),
        "status_breakdown": {s.lower(): db["complaints"].count_documents({"status": s}) for s in ["Submitted", "In Review", "In Progress", "Resolved", "Rejected", "Reported"]}
    }

@router.get("/analytics")
def analytics():
    results = list(get_database()["complaints"].aggregate([{"$group": {"_id": "$category", "count": {"$sum": 1}}}]))
    return {"complaints_by_category": results}

@router.get("/heatmap")
def get_heatmap_data():
    return [{"lat": c["latitude"], "lng": c["longitude"], "category": c["category"]} for c in get_database()["complaints"].find({}, {"latitude": 1, "longitude": 1, "category": 1, "_id": 0})]

@router.put("/admin/verify/{complaint_id}")
def verify_complaint(complaint_id: str, payload: AdminVerifyRequest):
    db = get_database()
    c = db["complaints"].find_one({"complaint_id": complaint_id})
    if not c: raise HTTPException(status_code=404)
    
    if payload.category.lower() == "no issue":
        db["complaints"].update_one({"complaint_id": complaint_id}, {"$set": {"status": "Rejected", "category": "No Issue"}})
        return {"message": "Rejected"}
        
    letter = generate_complaint_letter(complaint_id, payload.category, c["latitude"], c["longitude"], c["location_name"], now_utc())
    pdf = generate_pdf_letter(complaint_id, letter)
    db["complaints"].update_one({"complaint_id": complaint_id}, {"$set": {"status": "Submitted", "category": payload.category, "letter": letter, "pdf_path": pdf}})
    return {"message": "Verified", "pdf_download_url": f"/download/{complaint_id}"}

@router.put("/complaint/{complaint_id}/letter")
def update_complaint_letter(complaint_id: str, payload: dict):
    db = get_database()
    letter = payload.get("letter")
    if not letter:
        raise HTTPException(status_code=400, detail="Letter content required")
    
    result = db["complaints"].update_one({"complaint_id": complaint_id}, {"$set": {"letter": letter}})
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Complaint not found")
    
    # Also regenerate PDF with new letter
    generate_pdf_letter(complaint_id, letter)
    
    return {"message": "Letter updated successfully"}

@router.put("/complaint/{complaint_id}/status")
def update_complaint_status(complaint_id: str, payload: StatusUpdate):
    db = get_database()
    result = db["complaints"].find_one_and_update(
        {"complaint_id": complaint_id},
        {"$set": {"status": payload.status, "updated_at": now_utc()}},
        return_document=ReturnDocument.AFTER
    )
    if not result:
        raise HTTPException(status_code=404, detail="Complaint not found")
    return {"message": "Status updated successfully", "new_status": result["status"]}

# --- EMERGENCY ENDPOINTS ---

@router.post("/emergency/report")
def report_emergency(payload: EmergencyReportRequest):
    complaint_id, submitted_at = str(uuid.uuid4()), now_utc()
    file_path = os.path.join(UPLOAD_FOLDER, f"{complaint_id}.jpg").replace('\\', '/')
    Image.open(BytesIO(base64.b64decode(payload.image.split(",")[-1]))).convert("RGB").save(file_path, "JPEG")
    
    image_url = None
    try: image_url = upload_complaint_image(file_path, complaint_id)
    except: pass

    loc_name, city_name, addr = get_location_details(payload.latitude, payload.longitude)
    
    # Generate formal letter for emergency
    letter_text = generate_complaint_letter(complaint_id, payload.category, payload.latitude, payload.longitude, loc_name, submitted_at, city_name=city_name)
    pdf_path = generate_pdf_letter(complaint_id, letter_text)

    doc = {
        "complaint_id": complaint_id, "category": payload.category, "priority": "CRITICAL", "is_emergency": True,
        "latitude": payload.latitude, "longitude": payload.longitude, "city": city_name, "location_name": loc_name,
        "address": addr, "short_text": payload.short_text, "image_path": file_path, "image_url": image_url,
        "letter": letter_text, "pdf_path": pdf_path,
        "status": "Reported", "created_at": submitted_at.isoformat(), "updated_at": submitted_at,
        "reporter_email": (payload.reporter_email or "").strip().lower()
    }
    get_database()["complaints"].insert_one(doc)
    try: send_emergency_alert_email(ADMIN_ALERT_EMAILS, complaint_id, payload.category, loc_name, payload.latitude, payload.longitude, submitted_at.isoformat(), file_path)
    except: pass
    return {
        "complaint": {
            "complaint_id": complaint_id, 
            "status": "Reported",
            "category": payload.category
        }, 
        "letter": letter_text,
        "pdf_download_url": f"/download/{complaint_id}",
        "message": "Emergency Reported"
    }

@router.post("/emergency/sos")
def send_sos(payload: SosRequest):
    complaint_id, submitted_at = str(uuid.uuid4()), now_utc()
    loc_name, city_name, addr = get_location_details(payload.latitude, payload.longitude)
    doc = {
        "complaint_id": complaint_id, "category": "SOS", "priority": "CRITICAL", "is_emergency": True,
        "latitude": payload.latitude, "longitude": payload.longitude, "city": city_name, "location_name": loc_name,
        "address": addr, "short_text": payload.note, "status": "Reported", "created_at": submitted_at.isoformat(),
        "reporter_email": (payload.reporter_email or "").strip().lower()
    }
    get_database()["complaints"].insert_one(doc)
    
    # Notify Admins immediately via email
    try:
        send_emergency_alert_email(
            ADMIN_ALERT_EMAILS, 
            complaint_id, 
            "SOS ALERT", 
            loc_name, 
            payload.latitude, 
            payload.longitude, 
            submitted_at.isoformat(),
            None # No image for SOS
        )
    except Exception as e:
        print(f"Failed to send SOS email: {e}")

    return {"complaint": {"complaint_id": complaint_id, "status": "Reported"}, "message": "SOS Sent"}

@router.get("/emergency/{complaint_id}/status")
def get_emergency_status(complaint_id: str):
    c = get_database()["complaints"].find_one({"complaint_id": complaint_id, "is_emergency": True}, {"_id": 0, "status": 1, "priority": 1})
    if not c: raise HTTPException(status_code=404)
    return c
