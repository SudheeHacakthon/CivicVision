from fastapi import APIRouter, UploadFile, File, Form
from app.database.mongodb import get_database
from datetime import datetime
import random
import uuid
import os

router = APIRouter()

UPLOAD_FOLDER = "uploads"

# Ensure uploads folder exists
os.makedirs(UPLOAD_FOLDER, exist_ok=True)


@router.post("/predict")
async def predict(
    file: UploadFile = File(...),
    latitude: float = Form(...),
    longitude: float = Form(...)
):

    complaint_id = str(uuid.uuid4())
    file_path = os.path.join(UPLOAD_FOLDER, f"{complaint_id}.jpg")

    # Save image locally
    with open(file_path, "wb") as buffer:
        buffer.write(await file.read())

    # Dummy classification (temporary)
    categories = ["Pothole", "Garbage Dump", "Broken Streetlight"]
    category = random.choice(categories)
    confidence = round(random.uniform(0.80, 0.98), 2)

    # ✅ Generate letter AFTER category is defined
    letter_text = generate_complaint_letter(category, latitude, longitude)

    db = get_database()

    complaint_data = {
        "complaint_id": complaint_id,
        "category": category,
        "confidence": confidence,
        "latitude": latitude,
        "longitude": longitude,
        "image_path": file_path,
        "letter": letter_text,
        "status": "Submitted",
        "created_at": datetime.utcnow()
    }

    db["complaints"].insert_one(complaint_data)

    return {
        "complaint_id": complaint_id,
        "category": category,
        "confidence": confidence,
        "status": "Submitted",
        "letter": letter_text
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




def generate_complaint_letter(category, latitude, longitude):
    return f"""
To,
The Municipal Commissioner,
[City Name]

Subject: Complaint regarding {category} at coordinates ({latitude}, {longitude})

Respected Sir/Madam,

I would like to bring to your attention that a {category} has been observed at the above-mentioned location.
This issue is causing inconvenience to the public and may pose safety risks if not addressed promptly.

I kindly request the concerned department to take necessary action at the earliest.

Thanking you.

Sincerely,
A Responsible Citizen
"""

from fastapi import HTTPException
from pydantic import BaseModel

class StatusUpdate(BaseModel):
    status: str


@router.put("/complaint/{complaint_id}/status")
def update_status(complaint_id: str, update: StatusUpdate):
    db = get_database()

    allowed_statuses = ["Submitted", "In Progress", "Resolved"]

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
