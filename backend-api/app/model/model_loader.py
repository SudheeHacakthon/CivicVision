import numpy as np
import tensorflow as tf
from tensorflow.keras.preprocessing import image

import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE_DIR, "civic_model.keras")

model = tf.keras.models.load_model(MODEL_PATH)


model = tf.keras.models.load_model(MODEL_PATH)

CLASS_NAMES = ["Garbage", "No Issue", "Pothole", "Road Crack"]

def predict_image(img_path):
    img = image.load_img(img_path, target_size=(224, 224))
    img_array = image.img_to_array(img)
    img_array = np.expand_dims(img_array, axis=0)
    img_array = img_array / 255.0

    predictions = model.predict(img_array)
    confidence = float(np.max(predictions))
    class_index = np.argmax(predictions)
    category = CLASS_NAMES[class_index]

    return {
        "category": category,
        "confidence": round(confidence, 2)
    }
