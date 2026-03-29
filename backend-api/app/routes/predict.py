from fastapi import APIRouter, UploadFile, File, Form, Request
import base64
from io import BytesIO
from PIL import Image
import numpy as np
from app.database.mongodb import get_database
from datetime import datetime
import random
import uuid
import os
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import ListFlowable
from fastapi.responses import FileResponse
import requests
from fastapi import HTTPException
from pydantic import BaseModel


router = APIRouter()

UPLOAD_FOLDER = "uploads"

# Ensure uploads folder exists
os.makedirs(UPLOAD_FOLDER, exist_ok=True)


@router.post("/predict")
async def predict(
    request: Request,
    image: str = Form(None),
    file: UploadFile = File(None),
    latitude: float = Form(None),
    longitude: float = Form(None)
):
    complaint_id = str(uuid.uuid4())

    # Accept JSON payload from web and multipart/form-data from mobile.
    if request.headers.get("content-type", "").startswith("application/json"):
        payload = await request.json()
        image = payload.get("image")
        latitude = payload.get("latitude")
        longitude = payload.get("longitude")

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
        image_pil.save(file_path)
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

    location_name, city_name = get_location_details(latitude, longitude)


    #  generate letter with complaint_id
    letter_text = generate_complaint_letter(
        complaint_id, category, latitude, longitude, location_name
    )

    #  generate pdf
    pdf_path = generate_pdf_letter(complaint_id, letter_text)

    db = get_database()

    complaint_data = {
        "complaint_id": complaint_id,
        "category": category,
        "confidence": confidence,
        "latitude": latitude,
        "longitude": longitude,
        "city": city_name,
        "location_name": location_name,
        "image_path": file_path,
        "pdf_path": pdf_path,
        "letter": letter_text,
        "status": "Submitted",
        "created_at": datetime.utcnow()
    }

    db["complaints"].insert_one(complaint_data)

    return {
        "complaint": {
            "complaint_id": complaint_id,
            "category": category,
            "confidence": confidence,
            "status": "Submitted"
        },
        "location": {
            "latitude": latitude,
            "longitude": longitude,
            "city": city_name,
            "location_name": location_name
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


@router.get("/complaint/{complaint_id}")
def get_complaint(complaint_id: str):
    db = get_database()
    complaint = db["complaints"].find_one(
        {"complaint_id": complaint_id},
        {"_id": 0}
    )
    return complaint

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
    resolved = db["complaints"].count_documents({"status": "Resolved"})
    rejected = db["complaints"].count_documents({"status": "Rejected"})

    return {
        "total_complaints": total,
        "status_breakdown": {
            "submitted": submitted,
            "in_review": in_review,
            "in_progress": in_progress,
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
    location_name, _ = get_location_details(latitude, longitude)
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

        response = requests.get(url, params=params, headers=headers)
        data = response.json()

        address = data.get("address", {})

        suburb = address.get("suburb") or address.get("neighbourhood")
        city = address.get("city") or address.get("town") or address.get("village")
        state = address.get("state")

        parts = [suburb, city, state]
        location = ", ".join([p for p in parts if p])
        fallback_city = city or state or "Unknown"

        return (
            location if location else f"coordinates ({latitude}, {longitude})",
            fallback_city
        )

    except Exception:
        return (f"coordinates ({latitude}, {longitude})", "Unknown")

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

def generate_complaint_letter(complaint_id, category, latitude, longitude, location_name=None):
    location_name = location_name or get_location_name(latitude, longitude)
    authority_name, department = get_relevant_authority(category)

    today_date = datetime.utcnow().strftime("%d %B %Y")

    return f"""
Date: {today_date}

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

    allowed_statuses = ["Submitted", "In Review", "In Progress", "Resolved", "Rejected"]

    if update.status not in allowed_statuses:
        raise HTTPException(status_code=400, detail="Invalid status value")

    result = db["complaints"].update_one(
        {"complaint_id": complaint_id},
        {
            "$set": {
                "status": update.status,
                "updated_at": datetime.utcnow()
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
