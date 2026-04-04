import numpy as np
import tensorflow as tf
from tensorflow.keras.preprocessing import image
import json

import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE_DIR, "civic_model.keras")
CLASS_NAMES_PATH = os.path.join(BASE_DIR, "class_names.json")
CONFIDENCE_THRESHOLD = 0.65

model = tf.keras.models.load_model(MODEL_PATH)


def _load_class_names():
    if os.path.exists(CLASS_NAMES_PATH):
        try:
            with open(CLASS_NAMES_PATH, "r", encoding="utf-8") as class_names_file:
                class_names = json.load(class_names_file)
            if isinstance(class_names, list) and class_names:
                return class_names
        except Exception:
            pass

    return ["Garbage", "No Issue", "Pothole", "Road Crack"]


CLASS_NAMES = _load_class_names()

def predict_image(img_path):
    img = image.load_img(img_path, target_size=(224, 224))
    img_array = image.img_to_array(img)
    img_array = np.expand_dims(img_array, axis=0)
    img_array = img_array / 255.0

    predictions = model.predict(img_array, verbose=0)[0]
    class_index = int(np.argmax(predictions))
    confidence = float(predictions[class_index])
    predicted_category = CLASS_NAMES[class_index]

    needs_review = confidence < CONFIDENCE_THRESHOLD
    category = "Needs Review" if needs_review else predicted_category

    top_indices = np.argsort(predictions)[::-1][:3]
    top_predictions = [
        {
            "category": CLASS_NAMES[int(idx)],
            "confidence": round(float(predictions[int(idx)]), 4),
        }
        for idx in top_indices
    ]

    return {
        "category": category,
        "confidence": round(confidence, 2),
        "predicted_category": predicted_category,
        "needs_review": needs_review,
        "top_predictions": top_predictions,
    }
