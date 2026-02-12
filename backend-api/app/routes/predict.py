from fastapi import APIRouter, UploadFile, File
from app.model.model_loader import predict_image


router = APIRouter()

@router.post("/predict")
async def predict(file: UploadFile = File(...)):
    image_data = await file.read()
    prediction = predict_image(image_data)
    return {"prediction": prediction}
