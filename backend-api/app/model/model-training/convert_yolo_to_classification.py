import os
import shutil
import random

image_dir = "road_dataset/data/images"
label_dir = "road_dataset/data/labels"

output_train = "dataset/train"
output_val = "dataset/val"

# Class mapping
class_map = {
    "0": "pothole",
    "1": "crack",
    "2": "manhole"
}

# Create folders
for split in ["train", "val"]:
    for class_name in class_map.values():
        os.makedirs(f"dataset/{split}/{class_name}", exist_ok=True)

# Get all images
images = [f for f in os.listdir(image_dir) if f.endswith((".jpg", ".png", ".jpeg"))]

random.shuffle(images)

split_index = int(0.8 * len(images))

train_images = images[:split_index]
val_images = images[split_index:]

def process_images(image_list, split_type):
    for img_name in image_list:
        label_path = os.path.join(label_dir, img_name.replace(".jpg", ".txt").replace(".png", ".txt"))
        
        if not os.path.exists(label_path):
            continue
        
        with open(label_path, "r") as f:
            first_line = f.readline().strip()
            class_id = first_line.split()[0]

        class_name = class_map[class_id]

        src = os.path.join(image_dir, img_name)
        dst = os.path.join(f"dataset/{split_type}/{class_name}", img_name)

        shutil.copy(src, dst)

process_images(train_images, "train")
process_images(val_images, "val")

print("Dataset converted successfully!")
