import tensorflow as tf
from tensorflow.keras.models import load_model
from tensorflow.keras.preprocessing import image
import numpy as np
import sys
import os

# ==========================
# Load Model
# ==========================
print("Loading model...")
model = load_model("civic_model.keras")
print("Model loaded successfully!\n")

# ==========================
# Class Names (MUST match train.py order)
# ==========================
class_names = ["crack", "garbage", "plain", "pothole"]

# ==========================
# Get Image Path
# ==========================
if len(sys.argv) > 1:
    img_path = sys.argv[1]
else:
    print("Usage: python test_model.py <image_path>")
    sys.exit(1)

if not os.path.exists(img_path):
    print("Image not found:", img_path)
    sys.exit(1)

print(f"Testing image: {img_path}\n")

# ==========================
# Preprocess Image
# ==========================
img = image.load_img(img_path, target_size=(224, 224))
img_array = image.img_to_array(img)
img_array = np.expand_dims(img_array, axis=0)
img_array = img_array / 255.0

# ==========================
# Predict
# ==========================
predictions = model.predict(img_array)
confidence = np.max(predictions)
predicted_class = class_names[np.argmax(predictions)]

# ==========================
# Print Results
# ==========================
print(f"Prediction: {predicted_class}")
print(f"Confidence: {confidence*100:.2f}%\n")

print("All class probabilities:")
for i, prob in enumerate(predictions[0]):
    print(f"{class_names[i]}: {prob*100:.2f}%")
