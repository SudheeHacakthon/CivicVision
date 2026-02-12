from fastapi import APIRouter, UploadFile, File
from app.database.mongodb import get_database
from datetime import datetime
import random
import uuid

router = APIRouter()

@router.post("/predict")
async def predict(file: UploadFile = File(...)):

    # Dummy classification (temporary)
    categories = ["Pothole", "Garbage Dump", "Broken Streetlight"]
    category = random.choice(categories)
    confidence = round(random.uniform(0.80, 0.98), 2)

    complaint_id = str(uuid.uuid4())

    db = get_database()

    complaint_data = {
        "complaint_id": complaint_id,
        "category": category,
        "confidence": confidence,
        "status": "Submitted",
        "created_at": datetime.utcnow()
    }

    db["complaints"].insert_one(complaint_data)

    return {
        "complaint_id": complaint_id,
        "category": category,
        "confidence": confidence,
        "status": "Submitted"
    }
