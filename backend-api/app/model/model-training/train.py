import tensorflow as tf
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense, GlobalAveragePooling2D, Dropout
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.optimizers import Adam
from tensorflow.keras.callbacks import EarlyStopping
from tensorflow.keras.utils import load_img, img_to_array, save_img
import os
import json
import numpy as np
import random
from pathlib import Path
from sklearn.metrics import classification_report
from sklearn.utils.class_weight import compute_class_weight

print("TensorFlow version:", tf.__version__)
print("GPU Available:", tf.config.list_physical_devices('GPU'))

# ==========================
# Dataset Paths
# ==========================
SCRIPT_DIR = Path(__file__).resolve().parent
train_dir = SCRIPT_DIR / "dataset" / "train"
val_dir = SCRIPT_DIR / "dataset" / "val"

# ==========================
# Dataset Balancing Targets
# ==========================
TARGET_TRAIN_IMAGES = 400
SEED = 42
SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}

# Safe augmentation settings for civic-image classification.
balance_augmenter = ImageDataGenerator(
    rotation_range=15,
    width_shift_range=0.08,
    height_shift_range=0.08,
    zoom_range=0.12,
    brightness_range=(0.85, 1.15),
    horizontal_flip=True,
    fill_mode="nearest",
)


def _list_image_files(class_dir: Path):
    return [
        p for p in sorted(class_dir.iterdir())
        if p.is_file() and p.suffix.lower() in SUPPORTED_EXTENSIONS
    ]


def _rebalance_class_dir(class_dir: Path, target_count: int, rng: random.Random, allow_delete: bool = False):
    files = _list_image_files(class_dir)
    start_count = len(files)
    deleted = 0
    augmented = 0

    if allow_delete and start_count > target_count:
        to_delete = rng.sample(files, start_count - target_count)
        for file_path in to_delete:
            file_path.unlink(missing_ok=True)
        deleted = len(to_delete)

    files = _list_image_files(class_dir)
    if len(files) < target_count:
        if not files:
            raise RuntimeError(
                f"Cannot augment class '{class_dir.name}' because it has zero source images."
            )

        needed = target_count - len(files)
        source_files = list(files)

        for idx in range(needed):
            source_path = rng.choice(source_files)

            image = load_img(source_path)
            image_array = img_to_array(image)
            transformed = balance_augmenter.random_transform(
                image_array,
                seed=rng.randint(0, 10_000_000),
            )
            transformed = np.clip(transformed, 0, 255).astype(np.uint8)

            output_path = class_dir / f"aug_{source_path.stem}_{idx + 1:04d}.jpg"
            while output_path.exists():
                output_path = class_dir / f"aug_{source_path.stem}_{idx + 1:04d}_{rng.randint(1000, 9999)}.jpg"

            save_img(output_path, transformed)
            augmented += 1

    end_count = len(_list_image_files(class_dir))
    return {
        "start": start_count,
        "deleted": deleted,
        "augmented": augmented,
        "end": end_count,
    }


def rebalance_dataset(train_root: Path, val_root: Path):
    train_path = Path(train_root)
    val_path = Path(val_root)

    if not train_path.exists() or not val_path.exists():
        raise FileNotFoundError("Train/validation directories not found for balancing.")

    train_classes = {p.name for p in train_path.iterdir() if p.is_dir()}
    val_classes = {p.name for p in val_path.iterdir() if p.is_dir()}
    classes = sorted(train_classes | val_classes)

    rng = random.Random(SEED)
    print("\nRebalancing TRAIN dataset only (validation set left untouched)...")
    print(f"Target per class -> train: {TARGET_TRAIN_IMAGES}")

    for class_name in classes:
        class_train_dir = train_path / class_name
        class_train_dir.mkdir(parents=True, exist_ok=True)

        train_stats = _rebalance_class_dir(
            class_train_dir,
            TARGET_TRAIN_IMAGES,
            rng,
            allow_delete=False,
        )

        print(
            f"[{class_name}] "
            f"train {train_stats['start']} -> {train_stats['end']} "
            f"(del {train_stats['deleted']}, aug {train_stats['augmented']})"
        )


# ==========================
# Image Parameters
# ==========================
IMG_SIZE = 224
BATCH_SIZE = 32
EPOCHS = 18
HEAD_EPOCHS = 8
FINE_TUNE_EPOCHS = max(EPOCHS - HEAD_EPOCHS, 1)
FINE_TUNE_AT = 120

# Rebalance class counts before creating generators.
rebalance_dataset(train_dir, val_dir)

if os.getenv("BALANCE_ONLY", "0") == "1":
    print("\nBALANCE_ONLY=1 -> dataset balancing completed. Exiting before training.")
    raise SystemExit(0)

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
    str(train_dir),
    target_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    class_mode='categorical'
)

val_generator = val_datagen.flow_from_directory(
    str(val_dir),
    target_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    class_mode='categorical'
)

print("\nClasses detected:")
print(train_generator.class_indices)

num_classes = len(train_generator.class_indices)
class_names = [
    class_name for class_name, _ in sorted(train_generator.class_indices.items(), key=lambda kv: kv[1])
]

class_weight_values = compute_class_weight(
    class_weight='balanced',
    classes=np.unique(train_generator.classes),
    y=train_generator.classes,
)
class_weights = {int(i): float(w) for i, w in enumerate(class_weight_values)}

print("\nClass weights:")
for idx, weight in class_weights.items():
    print(f"  {class_names[idx]} -> {weight:.4f}")

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

early_stopping = EarlyStopping(
    monitor="val_loss",
    patience=3,
    restore_best_weights=True,
    verbose=1,
)

history = model.fit(
    train_generator,
    validation_data=val_generator,
    epochs=HEAD_EPOCHS,
    callbacks=[early_stopping],
    class_weight=class_weights,
)

print("\nStarting fine-tuning...\n")
base_model.trainable = True
for layer in base_model.layers[:FINE_TUNE_AT]:
    layer.trainable = False

model.compile(
    optimizer=Adam(learning_rate=1e-5),
    loss='categorical_crossentropy',
    metrics=['accuracy']
)

fine_tune_early_stopping = EarlyStopping(
    monitor="val_loss",
    patience=3,
    restore_best_weights=True,
    verbose=1,
)

model.fit(
    train_generator,
    validation_data=val_generator,
    epochs=FINE_TUNE_EPOCHS,
    callbacks=[fine_tune_early_stopping],
    class_weight=class_weights,
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

report = classification_report(y_true, y_pred, target_names=class_names, digits=4)
print("\nClassification Report (Validation Set):")
print(report)

# ==========================
# Save Model
# ==========================
output_model_path = SCRIPT_DIR.parent / "civic_model.keras"
output_class_names_path = SCRIPT_DIR.parent / "class_names.json"

model.save(str(output_model_path))
with open(output_class_names_path, "w", encoding="utf-8") as class_names_file:
    json.dump(class_names, class_names_file, indent=2)

print("\n===================================")
print("Training completed successfully!")
print(f"Model saved as: {output_model_path}")
print(f"Class names saved as: {output_class_names_path}")
print("===================================")
