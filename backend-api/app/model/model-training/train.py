import tensorflow as tf
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense, GlobalAveragePooling2D, Dropout
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.optimizers import Adam
import os
import numpy as np
from sklearn.metrics import classification_report

print("TensorFlow version:", tf.__version__)
print("GPU Available:", tf.config.list_physical_devices('GPU'))

# ==========================
# Dataset Paths
# ==========================
train_dir = "dataset/train"
val_dir = "dataset/val"

# ==========================
# Image Parameters
# ==========================
IMG_SIZE = 224
BATCH_SIZE = 32
EPOCHS = 10

# ==========================
# Data Generators
# ==========================
train_datagen = ImageDataGenerator(
    rescale=1./255,
    rotation_range=20,
    zoom_range=0.2,
    horizontal_flip=True
)

val_datagen = ImageDataGenerator(rescale=1./255)

train_generator = train_datagen.flow_from_directory(
    train_dir,
    target_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    class_mode='categorical'
)

val_generator = val_datagen.flow_from_directory(
    val_dir,
    target_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    class_mode='categorical'
)

print("\nClasses detected:")
print(train_generator.class_indices)

num_classes = len(train_generator.class_indices)

# ==========================
# Load MobileNetV2 Base
# ==========================
base_model = MobileNetV2(
    weights='imagenet',
    include_top=False,
    input_shape=(IMG_SIZE, IMG_SIZE, 3)
)

base_model.trainable = False

# ==========================
# Build Model
# ==========================
model = Sequential([
    base_model,
    GlobalAveragePooling2D(),
    Dense(128, activation='relu'),
    Dropout(0.5),
    Dense(num_classes, activation='softmax')
])

# ==========================
# Compile Model
# ==========================
model.compile(
    optimizer=Adam(learning_rate=0.0001),
    loss='categorical_crossentropy',
    metrics=['accuracy']
)

print("\nModel Summary:")
model.summary()

# ==========================
# Train Model
# ==========================
print("\nStarting training...\n")

history = model.fit(
    train_generator,
    validation_data=val_generator,
    epochs=EPOCHS
)

print("\nGenerating classification report on validation set...")

# Collect predictions and labels from validation generator
val_generator.reset()
y_true = []
y_pred = []

for batch_x, batch_y in val_generator:
    batch_pred = model.predict(batch_x, verbose=0)
    y_pred.extend(np.argmax(batch_pred, axis=1))
    y_true.extend(np.argmax(batch_y, axis=1))
    if len(y_true) >= val_generator.samples:
        break

class_names = list(train_generator.class_indices.keys())
report = classification_report(y_true, y_pred, target_names=class_names, digits=4)
print("\nClassification Report (Validation Set):")
print(report)

# ==========================
# Save Model
# ==========================
model.save("civic_model.keras")   # modern format

print("\n===================================")
print("Training completed successfully!")
print("Model saved as: civic_model.keras")
print("===================================")
