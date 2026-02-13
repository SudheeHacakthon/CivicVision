import tensorflow as tf
from tensorflow.keras.models import load_model
from tensorflow.keras.preprocessing import image
import numpy as np
import sys

print("Loading model...")
model = load_model("civic_model.keras")
print("Model loaded successfully!")

# Class names (must match folder names exactly)
class_names = ['crack', 'garbage', 'plain', 'pothole']

if len(sys.argv) < 2:
    print("Usage: python test_model.py <image_path>")
    sys.exit(1)

img_path = sys.argv[1]
print(f"\nTesting image: {img_path}")

# Load image
img = image.load_img(img_path, target_size=(224, 224))
img_array = image.img_to_array(img)
img_array = np.expand_dims(img_array, axis=0)
img_array = img_array / 255.0

# Predict
predictions = model.predict(img_array)
predicted_index = np.argmax(predictions[0])
confidence = predictions[0][predicted_index]

print("\nPrediction:", class_names[predicted_index])
print(f"Confidence: {confidence:.2%}")

print("\nAll class probabilities:")
for i, prob in enumerate(predictions[0]):
    print(f"{class_names[i]}: {prob:.2%}")
