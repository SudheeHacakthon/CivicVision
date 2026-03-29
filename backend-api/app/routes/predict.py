from fastapi import APIRouter, UploadFile, File, Form, Request
import base64
from io import BytesIO
from PIL import Image
from app.database.mongodb import get_database
from app.services.email_service import send_emergency_alert_email
from datetime import datetime, timezone
import uuid
import os
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import inch
from fastapi.responses import FileResponse
import requests
from fastapi import HTTPException
from pydantic import BaseModel
from typing import Optional
from pymongo import ReturnDocument


router = APIRouter()

UPLOAD_FOLDER = "uploads"

def get_priority(category):
    if category in ["Pothole", "Road Crack"]:
        return "HIGH"
    elif category == "Garbage":
        return "MEDIUM"
    else:
        return "LOW"

# Ensure uploads folder exists
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

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
    
    # Web: base64 image, Mobile: uploaded file
    if image:
        # Support data URLs like: data:image/jpeg;base64,/9j/4AAQ...
        if "," in image:
            image = image.split(",", 1)[1]
        # Decode base64
        image_data = base64.b64decode(image)
        image_pil = Image.open(BytesIO(image_data)).convert('RGB')
        file_path = os.path.join(UPLOAD_FOLDER, f"{complaint_id}.jpg")
        image_pil.save(file_path, format="JPEG", quality=95, subsampling=0)
    elif file:
        # Mobile fallback
        file_path = os.path.join(UPLOAD_FOLDER, f"{complaint_id}.jpg")
        with open(file_path, "wb") as buffer:
            buffer.write(await file.read())
    else:
        raise HTTPException(status_code=400, detail="Provide either base64 image or file upload")

    from app.model.model_loader import predict_image
    prediction = predict_image(file_path)
    print("MODEL OUTPUT:", prediction)
    category = prediction["category"]
    confidence = prediction["confidence"]
    priority = get_priority(category)

    location_name, city_name, address_parts = get_location_details(latitude, longitude)


    #  generate letter with complaint_id
    letter_text = generate_complaint_letter(
        complaint_id, category, latitude, longitude, location_name, submitted_at
    )

    #  generate pdf
    pdf_path = generate_pdf_letter(complaint_id, letter_text)

    db = get_database()

    complaint_data = {
        "complaint_id": complaint_id,
        "category": category,
        "confidence": confidence,
        "priority": priority,
        "latitude": latitude,
        "longitude": longitude,
        "city": city_name,
        "location_name": location_name,
        "address": address_parts,
        "image_path": file_path,
        "pdf_path": pdf_path,
        "letter": letter_text,
        "status": "Submitted",
        "upvotes": 0,
        "created_at": submitted_at.isoformat(),
        "reporter_email": (reporter_email or "").strip().lower(),
    }

    db["complaints"].insert_one(complaint_data)

    return {
        "complaint": {
            "complaint_id": complaint_id,
            "category": category,
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
    return complaints


@router.get("/complaints/my")
def get_my_complaints(email: str):
    normalized_email = (email or "").strip().lower()
    if not normalized_email:
        raise HTTPException(status_code=400, detail="email is required")

    db = get_database()
    complaints = list(
        db["complaints"].find(
            {"reporter_email": normalized_email},
            {"_id": 0},
        )
    )
    return complaints


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
    file_path = os.path.join(UPLOAD_FOLDER, f"{complaint_id}.jpg")
    image_pil.save(file_path, format="JPEG", quality=95, subsampling=0)

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
        "status": "Reported",
        "upvotes": 0,
        "queue_bypassed": True,
        "created_at": submitted_at.isoformat(),
        "updated_at": submitted_at,
        "reporter_email": (payload.reporter_email or "").strip().lower(),
    }

    db["complaints"].insert_one(emergency_doc)
    db["admin_notifications"].insert_one(
        {
            "complaint_id": complaint_id,
            "kind": "EMERGENCY",
            "priority": "CRITICAL",
            "status": "pending",
            "message": f"Emergency {payload.category} reported at {location_name}",
            "created_at": submitted_at,
        }
    )

    # Notify configured admins immediately via email.
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
        # Email failure should not block emergency registration.
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
    db["admin_notifications"].insert_one(
        {
            "complaint_id": complaint_id,
            "kind": "SOS",
            "priority": "CRITICAL",
            "status": "pending",
            "message": f"SOS alert received at {location_name}",
            "created_at": submitted_at,
        }
    )

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
def update_emergency_status(complaint_id: str, update: "StatusUpdate"):
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
    complaint = db["complaints"].find_one(
        {"complaint_id": complaint_id},
        {"_id": 0}
    )
    return complaint


@router.post("/complaint/{complaint_id}/upvote")
def upvote_complaint(complaint_id: str):
    db = get_database()
    result = db["complaints"].find_one_and_update(
        {"complaint_id": complaint_id},
        {"$inc": {"upvotes": 1}},
        return_document=ReturnDocument.AFTER,
        projection={"_id": 0, "complaint_id": 1, "upvotes": 1},
    )

    if not result:
        raise HTTPException(status_code=404, detail="Complaint not found")

    return {
        "success": True,
        "complaint_id": complaint_id,
        "upvotes": int(result.get("upvotes", 0)),
    }


@router.get("/complaint/{complaint_id}/image")
def get_complaint_image(complaint_id: str):
    db = get_database()
    complaint = db["complaints"].find_one(
        {"complaint_id": complaint_id},
        {"_id": 0, "image_path": 1},
    )

    if not complaint:
        raise HTTPException(status_code=404, detail="Complaint not found")

    image_path = complaint.get("image_path")
    if not image_path or not os.path.exists(image_path):
        raise HTTPException(status_code=404, detail="Image not found")

    return FileResponse(image_path, media_type="image/jpeg")

@router.get("/download/{complaint_id}")
def download_pdf(complaint_id: str):
    pdf_path = f"uploads/{complaint_id}.pdf"

    if not os.path.exists(pdf_path):
        raise HTTPException(status_code=404, detail="PDF not found")

    return FileResponse(
        pdf_path,
        media_type="application/pdf",
        filename=f"{complaint_id}.pdf"
    )

@router.get("/admin/dashboard")
def admin_dashboard():
    db = get_database()

    total = db["complaints"].count_documents({})
    submitted = db["complaints"].count_documents({"status": "Submitted"})
    in_review = db["complaints"].count_documents({"status": "In Review"})
    in_progress = db["complaints"].count_documents({"status": "In Progress"})
    reported = db["complaints"].count_documents({"status": "Reported"})
    help_arriving = db["complaints"].count_documents({"status": "Help Arriving"})
    resolved = db["complaints"].count_documents({"status": "Resolved"})
    rejected = db["complaints"].count_documents({"status": "Rejected"})

    return {
        "total_complaints": total,
        "status_breakdown": {
            "submitted": submitted,
            "reported": reported,
            "in_review": in_review,
            "in_progress": in_progress,
            "help_arriving": help_arriving,
            "resolved": resolved,
            "rejected": rejected
        }
    }

@router.get("/analytics")
def analytics():
    db = get_database()

    pipeline = [
        {
            "$group": {
                "_id": "$category",
                "count": {"$sum": 1}
            }
        }
    ]

    results = list(db["complaints"].aggregate(pipeline))

    return {
        "complaints_by_category": results
    }

@router.get("/heatmap")
def get_heatmap_data():
    db = get_database()
    complaints = db["complaints"].find({}, {"_id": 0})

    heatmap_data = []

    for c in complaints:
        if "latitude" in c and "longitude" in c:
            heatmap_data.append({
                "lat": c["latitude"],
                "lng": c["longitude"],
                "category": c["category"]
            })

    return heatmap_data

def get_authority(category):
    mapping = {
        "Pothole": "Chief Engineer, Roads & Engineering Wing",
        "Garbage Dump": "Sanitation & Solid Waste Management Department",
        "Broken Streetlight": "Electrical & Street Lighting Wing"
    }
    return mapping.get(category, "Municipal Commissioner")


def get_location_name(latitude, longitude):
    location_name, _, _ = get_location_details(latitude, longitude)
    return location_name

def get_location_details(latitude, longitude):
    try:
        url = "https://nominatim.openstreetmap.org/reverse"
        params = {
            "lat": latitude,
            "lon": longitude,
            "format": "json"
        }

        headers = {
            "User-Agent": "civic-monitor-app"
        }

        response = requests.get(url, params=params, headers=headers, timeout=5)
        data = response.json()

        address = data.get("address", {})

        suburb = address.get("suburb")
        neighbourhood = address.get("neighbourhood")
        village = address.get("village")
        town = address.get("town")
        city = address.get("city") or town or village
        state = address.get("state")
        country = address.get("country")
        postcode = address.get("postcode")

        parts = [suburb or neighbourhood, village, town, city, state]
        location = ", ".join([p for p in parts if p])
        fallback_city = city or state or "Unknown"

        address_parts = {
            "suburb": suburb,
            "neighbourhood": neighbourhood,
            "village": village,
            "town": town,
            "city": city,
            "state": state,
            "country": country,
            "postcode": postcode,
        }

        return (
            location if location else f"coordinates ({latitude}, {longitude})",
            fallback_city,
            address_parts,
        )

    except Exception:
        return (
            f"coordinates ({latitude}, {longitude})",
            "Unknown",
            {
                "suburb": None,
                "neighbourhood": None,
                "village": None,
                "town": None,
                "city": None,
                "state": None,
                "country": None,
                "postcode": None,
            },
        )

def get_relevant_authority(category):

    if category == "Broken Streetlight":
        return (
            "Greater Hyderabad Municipal Corporation (GHMC), Hyderabad",
            "Electrical & Street Lighting Wing"
        )

    if category == "Pothole" or category=="Road Crack":
        return (
            "Greater Hyderabad Municipal Corporation (GHMC), Hyderabad",
            "Roads & Maintenance Department"
        )

    if category == "Garbage":
        return (
            "Greater Hyderabad Municipal Corporation (GHMC), Hyderabad",
            "Sanitation & Waste Management Department"
        )

    return (
        "Municipal Corporation",
        "Public Works Department"
    )

def generate_complaint_letter(
    complaint_id,
    category,
    latitude,
    longitude,
    location_name=None,
    submitted_at=None,
):
    location_name = location_name or get_location_name(latitude, longitude)
    authority_name, department = get_relevant_authority(category)

    submitted_at = submitted_at or now_utc()
    today_date = submitted_at.strftime("%d %B %Y")
    submitted_time_utc = submitted_at.strftime("%H:%M:%S UTC")

    return f"""
Date: {today_date}
Time: {submitted_time_utc}

To,
The Head,
{department},
{authority_name}.

Subject: Urgent Complaint regarding {category} at {location_name} ({latitude}, {longitude})

Respected Sir/Madam,

I would like to formally report a civic issue identified as "{category}" at the following location:

Area: {location_name}
Latitude: {latitude}
Longitude: {longitude}

This issue is currently causing inconvenience to the public and may pose safety hazards if not addressed promptly.

I request the concerned department to kindly inspect and resolve the matter at the earliest.

Complaint Reference ID: {complaint_id}

Thanking you.

Sincerely,
A Responsible Citizen
"""




class StatusUpdate(BaseModel):
    status: str


@router.put("/complaint/{complaint_id}/status")
def update_status(complaint_id: str, update: StatusUpdate):
    db = get_database()

    allowed_statuses = [
        "Submitted",
        "In Review",
        "In Progress",
        "Resolved",
        "Rejected",
        "Reported",
        "Help Arriving",
        "Closed",
    ]

    if update.status not in allowed_statuses:
        raise HTTPException(status_code=400, detail="Invalid status value")

    result = db["complaints"].update_one(
        {"complaint_id": complaint_id},
        {
            "$set": {
                "status": update.status,
                "updated_at": now_utc()
            }
        }
    )

    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Complaint not found")

    return {
        "message": "Status updated successfully",
        "complaint_id": complaint_id,
        "new_status": update.status
    }

def generate_pdf_letter(complaint_id, letter_text):

    pdf_path = f"uploads/{complaint_id}.pdf"

    doc = SimpleDocTemplate(pdf_path, pagesize=A4)
    elements = []

    styles = getSampleStyleSheet()
    normal_style = styles["Normal"]

    for line in letter_text.split("\n"):
        elements.append(Paragraph(line, normal_style))
        elements.append(Spacer(1, 0.2 * inch))

    doc.build(elements)

    return pdf_path
