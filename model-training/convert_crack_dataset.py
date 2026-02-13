import os
import shutil
import random

# Paths
source_train_images = "road_crack_dataset/train/images"
source_valid_images = "road_crack_dataset/valid/images"

dest_train = "dataset/train/crack"
dest_val = "dataset/val/crack"

os.makedirs(dest_train, exist_ok=True)
os.makedirs(dest_val, exist_ok=True)

# Collect images
train_images = [f for f in os.listdir(source_train_images) if f.endswith((".jpg", ".png", ".jpeg"))]
valid_images = [f for f in os.listdir(source_valid_images) if f.endswith((".jpg", ".png", ".jpeg"))]

# Copy train images
for img in train_images:
    shutil.copy(
        os.path.join(source_train_images, img),
        os.path.join(dest_train, img)
    )

# Copy val images
for img in valid_images:
    shutil.copy(
        os.path.join(source_valid_images, img),
        os.path.join(dest_val, img)
    )

print("Crack dataset added successfully!")
