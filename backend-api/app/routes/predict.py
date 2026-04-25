from fastapi import APIRouter, UploadFile, File, Form, Request, HTTPException
import base64
from io import BytesIO
from PIL import Image
from app.database.mongodb import get_database
from app.services.email_service import send_emergency_alert_email
from app.services.cloudinary_service import upload_complaint_image
from app.services.email_service import send_status_update_email
from app.services.duplicate_service import check_duplicate, get_embedding, add_embedding_to_issue
from bson import ObjectId
from datetime import datetime, timezone
import uuid
import os
import math
import logging
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import inch
from fastapi.responses import FileResponse, RedirectResponse
import requests
from pydantic import BaseModel
from typing import Optional
from pymongo import ReturnDocument

RADIUS_MAP = {
    "garbage": 50,
    "pothole": 30,
    "road crack": 25,
}

DEFAULT_RADIUS = 35


router = APIRouter()
logger = logging.getLogger(__name__)

UPLOAD_FOLDER = "uploads"

# Ensure uploads folder exists
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

def get_radius(category):
    if not category:
        return DEFAULT_RADIUS
    return RADIUS_MAP.get(category.strip().lower(), DEFAULT_RADIUS)

def get_priority(category,score):
    if score>4.0:
        return "HIGH"
    elif score>2.0 and score<4.0:
        return "MEDIUM"
    else:
        return "LOW"

def compute_priority(v, t, rho, category, confidence):
    if category.lower() == "no issue":
        return 0.0 if confidence < 0.8 else 0.2
    Vmax = 100
    rho_max = 10000
    lambda_ = 0.1

    w1, w2, w3, w4 = 0.4, 0.2, 0.2, 0.2  # weights

    # U(x)
    U = min(1, v / Vmax) * math.exp(-lambda_ * t)

    # D(x)
    D = rho / rho_max

    # C(x)
    CATEGORY_WEIGHTS = {
        "pothole": 0.9,
        "road crack": 0.85,
        "garbage": 0.6,
    }
    C = CATEGORY_WEIGHTS.get(category.lower(), 0.5)

    # Confidence (extra factor)
    conf = confidence  # already 0–1

    # Final score
    return w1 * U + w2 * D + w3 * C + w4 * conf

EMERGENCY_STATUS_FLOW = ["Reported", "In Progress", "Help Arriving", "Resolved", "Closed"]
ADMIN_ALERT_EMAILS = [
    "rizwik475@gmail.com",
    "priyanshunerella@gmail.com",
    "mjahnavi956@gmail.com",
]


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


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


class StatusUpdate(BaseModel):
    status: str


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

    # Accept JSON payload from web and multipart/form-data from mobile.
    if request.headers.get("content-type", "").startswith("application/json"):
        payload = await request.json()
        image = payload.get("image")
        latitude = payload.get("latitude")
        longitude = payload.get("longitude")
        reporter_email = payload.get("reporter_email")

    if latitude is None or longitude is None:
        raise HTTPException(status_code=400, detail="latitude and longitude are required")

    try:
        latitude = float(latitude)
        longitude = float(longitude)
    except (TypeError, ValueError):
        raise HTTPException(status_code=400, detail="latitude and longitude must be numbers")
    
    if image:
        # Support data URLs like: data:image/jpeg;base64,/9j/4AAQ...
        if "," in image:
            image = image.split(",", 1)[1]
        # Decode base64
        image_data = base64.b64decode(image)
        image_pil = Image.open(BytesIO(image_data)).convert('RGB')
    elif file:
        # Mobile fallback
        image_data = await file.read()
        image_pil = Image.open(BytesIO(image_data)).convert('RGB')
    else:
        raise HTTPException(status_code=400, detail="Provide either base64 image or file upload")

    # Save to local file path since model prediction/embedding still uses local files
    file_path = os.path.join(UPLOAD_FOLDER, f"{complaint_id}.jpg").replace('\\', '/')
    image_pil.save(file_path, format="JPEG", quality=95, subsampling=0)

    # Upload directly to Cloudinary from memory
    # This will raise HTTPException if upload fails, ensuring image_url is never None
    image_url = upload_complaint_image(image_pil, complaint_id)

    from app.model.model_loader import predict_image
    prediction = predict_image(file_path)
    category = prediction["category"]
    confidence = prediction["confidence"]
    priority = get_priority(category,confidence)
    v = 0 
    t = 0 
    rho = 5000 
    priority_score = compute_priority(v, t, rho, category, confidence)

    location_name, city_name, address_parts = get_location_details(latitude, longitude)

    letter_text = generate_complaint_letter(
        complaint_id, category, latitude, longitude, location_name, submitted_at
    )
    pdf_path = generate_pdf_letter(complaint_id, letter_text)

    db = get_database()
    normalized_category = category.strip().lower()
    issue_type = category.strip().title()
    email_clean = (reporter_email or "").strip().lower()

    new_embedding = get_embedding(file_path)

    duplicate_result = check_duplicate(
        db,
        {
            "lat": latitude,
            "lng": longitude,
            "type": issue_type,
            "image_path": file_path,
        },
        new_embedding=new_embedding,
    )

    if duplicate_result.get("duplicate"):
        if email_clean:
            db["complaints"].update_one(
                {"_id": ObjectId(duplicate_result["issue_id"])},
                {"$addToSet": {"subscribers": email_clean}}
            )
        add_embedding_to_issue(db, duplicate_result["issue_id"], new_embedding)

        return {
            "duplicate": True,
            "message": "Issue already reported. You'll receive updates.",
            "issue_id": duplicate_result["issue_id"]
        }

    complaint_data = {
        "complaint_id": complaint_id,
        "category": normalized_category,
        "type": issue_type,
        "confidence": confidence,
        "priority": priority,
        "priority_score": priority_score,
        "latitude": latitude,
        "longitude": longitude,
        "lat": latitude,
        "lng": longitude,
        "city": city_name,
        "location_name": location_name,
        "address": address_parts,
        "image_path": file_path,
        "image_url": image_url,
        "pdf_path": pdf_path,
        "letter": letter_text,
        "status": "Submitted",
        "upvotes": 0,
        "created_at": submitted_at.isoformat(),
        "reporter_email": email_clean,
        "subscribers": [email_clean] if email_clean else [],
        "embeddings": [new_embedding.tolist()],
    }

    db["complaints"].insert_one(complaint_data)

    return {
        "complaint": {
            "complaint_id": complaint_id,
            "category": normalized_category,
            "confidence": confidence,
            "status": "Submitted",
            "submitted_at": submitted_at.isoformat()
        },
        "location": {
            "latitude": latitude,
            "longitude": longitude,
            "city": city_name,
            "location_name": location_name,
            "address": address_parts,
        },
        "pdf_download_url": f"/download/{complaint_id}",
        "letter": letter_text,
        "message": "Complaint successfully registered"
    }


@router.get("/complaints")
def get_all_complaints():
    db = get_database()
    complaints = list(db["complaints"].find({}, {"_id": 0}))

    for c in complaints:
        

        v = c.get("upvotes", 0)
        category = c.get("category")
        raw_conf = c.get("confidence", 0)
        conf_map = {"low": 0.25, "medium": 0.5, "high": 0.75, "critical": 1.0}
        
        if isinstance(raw_conf, str):
            confidence = conf_map.get(raw_conf.lower(), 0)
        else:
            try:
                confidence = float(raw_conf)
            except Exception:
                confidence = 0
        
        created_at = c.get("created_at")
        t = 0
        if isinstance(created_at, str):
            created_time = datetime.fromisoformat(created_at)
            t = (datetime.now(timezone.utc) - created_time).days
        
        rho = 5000
        c["priority_score"] = compute_priority(v, t, rho, category, confidence)

    return complaints


@router.get("/complaints/my")
def get_my_complaints(email: str):
    normalized_email = (email or "").strip().lower()
    if not normalized_email:
        raise HTTPException(status_code=400, detail="email is required")

    db = get_database()
    return list(db["complaints"].find({"reporter_email": normalized_email}, {"_id": 0}))


@router.post("/emergency/report")
def report_emergency(payload: EmergencyReportRequest):
    complaint_id = str(uuid.uuid4())
    submitted_at = now_utc()
    image = payload.image
    if "," in image:
        image = image.split(",", 1)[1]

    try:
        image_data = base64.b64decode(image)
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Invalid image encoding") from exc

    image_pil = Image.open(BytesIO(image_data)).convert("RGB")
    # FIX: Path normalization
    file_path = os.path.join(UPLOAD_FOLDER, f"{complaint_id}.jpg").replace('\\', '/')
    image_pil.save(file_path, format="JPEG", quality=95, subsampling=0)

    # Upload directly to Cloudinary from memory
    # This will raise HTTPException if upload fails, ensuring image_url is never None
    image_url = upload_complaint_image(image_pil, complaint_id)

    location_name, city_name, address_parts = get_location_details(payload.latitude, payload.longitude)
    db = get_database()
    
    emergency_doc = {
        "complaint_id": complaint_id,
        "category": payload.category,
        "confidence": "critical",
        "priority": "CRITICAL",
        "is_emergency": True,
        "report_type": "EMERGENCY",
        "latitude": payload.latitude,
        "longitude": payload.longitude,
        "city": city_name,
        "location_name": location_name,
        "address": address_parts,
        "short_text": payload.short_text,
        "image_path": file_path,
        "image_url": image_url,
        "status": "Reported",
        "upvotes": 0,
        "queue_bypassed": True,
        "created_at": submitted_at.isoformat(),
        "updated_at": submitted_at,
        "reporter_email": (payload.reporter_email or "").strip().lower(),
    }

    db["complaints"].insert_one(emergency_doc)
    db["admin_notifications"].insert_one({
        "complaint_id": complaint_id,
        "kind": "EMERGENCY",
        "priority": "CRITICAL",
        "status": "pending",
        "message": f"Emergency {payload.category} reported at {location_name}",
        "created_at": submitted_at,
    })

    try:
        send_emergency_alert_email(
            recipients=ADMIN_ALERT_EMAILS,
            complaint_id=complaint_id,
            category=payload.category,
            location_name=location_name,
            latitude=payload.latitude,
            longitude=payload.longitude,
            reported_at_iso=submitted_at.isoformat(),
            image_path=file_path,
        )
    except Exception:
        pass

    return {
        "complaint": {
            "complaint_id": complaint_id,
            "category": payload.category,
            "priority": "CRITICAL",
            "status": "Reported",
        },
        "location": {
            "latitude": payload.latitude,
            "longitude": payload.longitude,
            "city": city_name,
            "location_name": location_name,
            "address": address_parts,
        },
        "status_flow": EMERGENCY_STATUS_FLOW[:3],
        "queue_bypassed": True,
        "admin_notification": "sent",
        "submitted_at": submitted_at.isoformat(),
    }


@router.post("/emergency/sos")
def send_sos(payload: SosRequest):
    complaint_id = str(uuid.uuid4())
    submitted_at = now_utc()
    location_name, city_name, address_parts = get_location_details(payload.latitude, payload.longitude)

    db = get_database()
    sos_doc = {
        "complaint_id": complaint_id,
        "category": "SOS",
        "priority": "CRITICAL",
        "is_emergency": True,
        "report_type": "EMERGENCY",
        "latitude": payload.latitude,
        "longitude": payload.longitude,
        "city": city_name,
        "location_name": location_name,
        "address": address_parts,
        "short_text": payload.note,
        "status": "Reported",
        "upvotes": 0,
        "queue_bypassed": True,
        "created_at": submitted_at.isoformat(),
        "updated_at": submitted_at,
        "reporter_email": (payload.reporter_email or "").strip().lower(),
    }
    db["complaints"].insert_one(sos_doc)
    db["admin_notifications"].insert_one({
        "complaint_id": complaint_id,
        "kind": "SOS",
        "priority": "CRITICAL",
        "status": "pending",
        "message": f"SOS alert received at {location_name}",
        "created_at": submitted_at,
    })

    return {
        "complaint": {
            "complaint_id": complaint_id,
            "category": "SOS",
            "priority": "CRITICAL",
            "status": "Reported",
        },
        "status_flow": EMERGENCY_STATUS_FLOW[:3],
        "queue_bypassed": True,
        "admin_notification": "sent",
        "submitted_at": submitted_at.isoformat(),
    }


@router.get("/emergency/{complaint_id}/status")
def get_emergency_status(complaint_id: str):
    db = get_database()
    complaint = db["complaints"].find_one(
        {"complaint_id": complaint_id, "is_emergency": True},
        {"_id": 0, "complaint_id": 1, "status": 1, "updated_at": 1, "priority": 1},
    )
    if not complaint:
        raise HTTPException(status_code=404, detail="Emergency complaint not found")
    return complaint


@router.put("/emergency/{complaint_id}/status")
def update_emergency_status(complaint_id: str, update: StatusUpdate):
    if update.status not in EMERGENCY_STATUS_FLOW:
        raise HTTPException(status_code=400, detail="Invalid emergency status value")

    db = get_database()
    result = db["complaints"].update_one(
        {"complaint_id": complaint_id, "is_emergency": True},
        {"$set": {"status": update.status, "updated_at": now_utc()}},
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Emergency complaint not found")

    return {
        "message": "Emergency status updated successfully",
        "complaint_id": complaint_id,
        "new_status": update.status,
    }


@router.get("/complaint/{complaint_id}")
def get_complaint(complaint_id: str):
    db = get_database()
    return db["complaints"].find_one({"complaint_id": complaint_id}, {"_id": 0})


@router.post("/complaint/{complaint_id}/upvote")
def upvote_complaint(complaint_id: str):
    db = get_database()
    result = db["complaints"].find_one_and_update(
        {"complaint_id": complaint_id},
        {"$inc": {"upvotes": 1}},
        return_document=ReturnDocument.AFTER,
    )
    if not result:
        raise HTTPException(status_code=404, detail="Complaint not found")
    
    new_upvotes = result.get("upvotes", 0)
    category = result.get("category")
    raw_conf = result.get("confidence", 0)
    conf_map = {"low": 0.25, "medium": 0.5, "high": 0.75, "critical": 1.0}
    
    if isinstance(raw_conf, str):
        confidence = conf_map.get(raw_conf.lower(), 0)
    else:
        confidence = float(raw_conf)
    
    created_at = result.get("created_at")
    t = 0
    if created_at:
        created_time = datetime.fromisoformat(created_at)
        t = (datetime.now(timezone.utc) - created_time).days

    rho = 5000
    new_priority = compute_priority(new_upvotes, t, rho, category, confidence)

    db["complaints"].update_one(
        {"complaint_id": complaint_id},
        {"$set": {"priority_score": new_priority}}
    )

    return {
        "success": True,
        "complaint_id": complaint_id,
        "upvotes": new_upvotes,
        "priority_score": new_priority
    }


@router.get("/complaint/{complaint_id}/image")
def get_complaint_image(complaint_id: str):
    db = get_database()
    complaint = db["complaints"].find_one(
        {"complaint_id": complaint_id},
        {"_id": 0, "image_path": 1, "image_url": 1},
    )

    if not complaint:
        raise HTTPException(status_code=404, detail="Complaint not found")

    # FIX: Use RedirectResponse so the app can actually see the image
    image_url = complaint.get("image_url")
    if image_url:
        return RedirectResponse(url=image_url)

    # FIX: Normalization for local fallback
    image_path = complaint.get("image_path")
    if image_path:
        normalized_path = image_path.replace('\\', '/')
        if os.path.exists(normalized_path):
            return FileResponse(normalized_path, media_type="image/jpeg")

    raise HTTPException(status_code=404, detail="Image not found")


@router.get("/download/{complaint_id}")
def download_pdf(complaint_id: str):
    pdf_path = f"uploads/{complaint_id}.pdf"
    if not os.path.exists(pdf_path):
        raise HTTPException(status_code=404, detail="PDF not found")
    return FileResponse(pdf_path, media_type="application/pdf", filename=f"{complaint_id}.pdf")


@router.get("/admin/dashboard")
def admin_dashboard():
    db = get_database()
    total = db["complaints"].count_documents({})
    def count_status(s): return db["complaints"].count_documents({"status": s})
    return {
        "total_complaints": total,
        "status_breakdown": {
            "submitted": count_status("Submitted"),
            "reported": count_status("Reported"),
            "in_review": count_status("In Review"),
            "in_progress": count_status("In Progress"),
            "help_arriving": count_status("Help Arriving"),
            "resolved": count_status("Resolved"),
            "rejected": count_status("Rejected")
        }
    }


@router.get("/analytics")
def analytics():
    db = get_database()
    pipeline = [{"$group": {"_id": "$category", "count": {"$sum": 1}}}]
    return {"complaints_by_category": list(db["complaints"].aggregate(pipeline))}


@router.get("/heatmap")
def get_heatmap_data():
    db = get_database()
    complaints = db["complaints"].find({}, {"_id": 0})
    return [{"lat": c["latitude"], "lng": c["longitude"], "category": c["category"]} for c in complaints if "latitude" in c]


def get_location_name(latitude, longitude):
    location_name, _, _ = get_location_details(latitude, longitude)
    return location_name


def get_location_details(latitude, longitude):
    try:
        url = "https://nominatim.openstreetmap.org/reverse"
        params = {"lat": latitude, "lon": longitude, "format": "json"}
        headers = {"User-Agent": "civic-monitor-app"}
        response = requests.get(url, params=params, headers=headers, timeout=5)
        data = response.json()
        address = data.get("address", {})
        suburb, neigh, vill, town, city, state = address.get("suburb"), address.get("neighbourhood"), address.get("village"), address.get("town"), address.get("city"), address.get("state")
        city_final = city or town or vill
        parts = [suburb or neigh, vill, town, city_final, state]
        location = ", ".join([p for p in parts if p])
        return (location or f"coords ({latitude}, {longitude})", city_final or state or "Unknown", address)
    except Exception:
        logger.exception("Failed to get location details")
        return (f"coords ({latitude}, {longitude})", "Unknown", {})


def get_relevant_authority(category):
    ghmc = "Greater Hyderabad Municipal Corporation (GHMC), Hyderabad"
    mapping = {
        "Broken Streetlight": (ghmc, "Electrical & Street Lighting Wing"),
        "Pothole": (ghmc, "Roads & Maintenance Department"),
        "Road Crack": (ghmc, "Roads & Maintenance Department"),
        "Garbage": (ghmc, "Sanitation & Waste Management Department")
    }
    return mapping.get(category, ("Municipal Corporation", "Public Works Department"))


def generate_complaint_letter(complaint_id, category, latitude, longitude, location_name=None, submitted_at=None):
    location_name = location_name or get_location_name(latitude, longitude)
    authority_name, department = get_relevant_authority(category)
    submitted_at = submitted_at or now_utc()
    today, time_utc = submitted_at.strftime("%d %B %Y"), submitted_at.strftime("%H:%M:%S UTC")
    return f"Date: {today}\nTime: {time_utc}\n\nTo,\nThe Head,\n{department},\n{authority_name}.\n\nSubject: Urgent Complaint regarding {category} at {location_name}\n\nRespected Sir/Madam,\n\nI report identification: {category}\nArea: {location_name}\nLat/Long: {latitude}, {longitude}\n\nPlease inspect.\nReference ID: {complaint_id}\n\nThanking you."


@router.put("/complaint/{complaint_id}/status")
def update_status(complaint_id: str, update: StatusUpdate):
    db = get_database()
    allowed = ["Submitted", "In Review", "In Progress", "Resolved", "Rejected", "Reported", "Help Arriving", "Closed"]
    if update.status not in allowed:
        raise HTTPException(status_code=400, detail="Invalid status")

    result = db["complaints"].update_one({"complaint_id": complaint_id}, {"$set": {"status": update.status, "updated_at": now_utc()}})
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Not found")
    
    complaint = db["complaints"].find_one({"complaint_id": complaint_id})
    if complaint:
        send_status_update_email(
            recipients=complaint.get("subscribers", []),
            complaint_id=complaint_id,
            new_status=update.status,
            category=complaint.get("category"),
            location_name=complaint.get("location_name"),
            latitude=complaint.get("latitude"),
            longitude=complaint.get("longitude"),
        )
    return {"message": "Status updated", "complaint_id": complaint_id, "new_status": update.status}


def generate_pdf_letter(complaint_id, letter_text):
    pdf_path = f"uploads/{complaint_id}.pdf"
    doc = SimpleDocTemplate(pdf_path, pagesize=A4)
    styles = getSampleStyleSheet()
    elements = []
    for line in letter_text.split("\n"):
        elements.append(Paragraph(line, styles["Normal"]))
        elements.append(Spacer(1, 0.2 * inch))
    doc.build(elements)
    return pdf_path