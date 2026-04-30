# backend-api/app/services/duplicate_service.py

import numpy as np
from sklearn.metrics.pairwise import cosine_similarity
from math import radians, cos, sin, asin, sqrt
from PIL import Image
from bson import ObjectId
import torch

from transformers import CLIPProcessor, CLIPModel

# ==========================
# 🔷 Load CLIP Model (once)
# ==========================
_model = None
_processor = None

def get_clip_model():
    global _model
    if _model is None:
        print("LOADING CLIP AI MODEL...")
        _model = CLIPModel.from_pretrained("openai/clip-vit-base-patch32")
        _model.eval()
    return _model

def get_clip_processor():
    global _processor
    if _processor is None:
        _processor = CLIPProcessor.from_pretrained("openai/clip-vit-base-patch32")
    return _processor

# ==========================
# 🔷 Config
# ==========================
EPS_CONFIG = {
    "Garbage": 70,      # meters
    "Pothole": 15,
    "Road Crack": 30
}

SIM_THRESHOLD = {
    "Garbage": 0.6,
    "Pothole": 0.7,
    "Road Crack": 0.65
}

TYPE_MAP = {
    "garbage": "Garbage",
    "pothole": "Pothole",
    "road crack": "Road Crack",
    "no issue": "No Issue",
}


def normalize_issue_type(issue_type):
    if not issue_type:
        return issue_type

    normalized = issue_type.strip()
    if not normalized:
        return normalized

    return TYPE_MAP.get(normalized.lower(), normalized.title())

# ==========================
# 🔷 Haversine Distance
# ==========================
def calculate_distance(lat1, lon1, lat2, lon2):
    """
    Returns distance in meters
    """
    R = 6371000  # meters

    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)

    a = sin(dlat/2)**2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon/2)**2
    c = 2 * asin(sqrt(a))

    return R * c


# ==========================
# 🔷 Get CLIP Embedding
# ==========================
def get_embedding(image_path):
    image = Image.open(image_path).convert("RGB")

    inputs = get_clip_processor()(images=image, return_tensors="pt")

    with torch.no_grad():
        features = get_clip_model().get_image_features(**inputs)

    if hasattr(features, "cpu"):   # tensor case
        embedding = features.cpu().numpy()[0]
    else:  # rare case fallback
        embedding = features[0].cpu().numpy()

    # normalize safely
    norm = np.linalg.norm(embedding)
    if norm == 0:
        return embedding

    embedding = embedding / norm

    return embedding


# ==========================
# 🔷 Cosine Similarity
# ==========================
def compute_similarity(emb1, emb2):
    emb1 = np.array(emb1).flatten()
    emb2 = np.array(emb2).flatten()

    return cosine_similarity([emb1], [emb2])[0][0]


# ==========================
# 🔷 Get Max Similarity (Best-match)
# ==========================
def get_max_similarity(new_emb, existing_embeddings):
    max_sim = 0

    for emb in existing_embeddings:
        try:
            emb = np.array(emb)   # 🔥 FIX: convert to numpy
            sim = compute_similarity(new_emb, emb)
            max_sim = max(max_sim, sim)
        except Exception as e:
            print("Embedding error:", e)   # 🔥 DEBUG
            continue

    return max_sim


# ==========================
# 🔷 Fetch Nearby Issues (DB)
# ==========================
def get_nearby_issues(db, lat, lng, issue_type, max_radius=200):
    """
    Query the complaints collection and support both new and legacy schemas.
    """
    issues = list(db["complaints"].find({
        "$or": [
            {"type": issue_type},
            {"category": issue_type.lower()}
        ]
    }))

    nearby = []

    for issue in issues:
        issue_lat = issue.get("lat", issue.get("latitude"))
        issue_lng = issue.get("lng", issue.get("longitude"))

        if issue_lat is None or issue_lng is None:
            continue

        dist = calculate_distance(lat, lng, issue_lat, issue_lng)

        if dist <= max_radius:
            nearby.append(issue)

    return nearby


# ==========================
# 🔷 MAIN FUNCTION
# ==========================
def check_duplicate(db, new_report, new_embedding=None):
    """
    new_report = {
        "lat": float,
        "lng": float,
        "type": str,
        "image_path": str
    }
    """

    issue_type = normalize_issue_type(new_report["type"])

    # 1️⃣ Ignore invalid
    if issue_type == "No Issue" or issue_type not in EPS_CONFIG:
      return {"duplicate": False}

    # 2️⃣ Get candidates
    candidates = get_nearby_issues(
        db,
        new_report["lat"],
        new_report["lng"],
        issue_type
    )

    if not candidates:
        return {"duplicate": False}

    # 3️⃣ New image embedding
    if new_embedding is None:
        new_embedding = get_embedding(new_report["image_path"])

    eps = EPS_CONFIG[issue_type]
    threshold = SIM_THRESHOLD[issue_type]

    # 4️⃣ Check each candidate cluster
    for issue in candidates:

        # Distance check
        issue_lat = issue.get("lat", issue.get("latitude"))
        issue_lng = issue.get("lng", issue.get("longitude"))

        if issue_lat is None or issue_lng is None:
            continue

        dist = calculate_distance(
            new_report["lat"],
            new_report["lng"],
            issue_lat,
            issue_lng
        )

        if dist > eps:
            continue

        # Get all embeddings from cluster
        cluster_embeddings = issue.get("embeddings", [])

        if not cluster_embeddings:
            continue

        # Best match similarity
        max_sim = get_max_similarity(new_embedding, cluster_embeddings)

        # 🔥 Decision
        if max_sim > threshold:
            return {
                "duplicate": True,
                "issue_id": str(issue["_id"]),
                "similarity": float(max_sim)
            }

    # 5️⃣ No match
    return {"duplicate": False}


# ==========================
# 🔷 Add embedding to issue
# ==========================
def add_embedding_to_issue(db, issue_id, embedding):
    if not isinstance(issue_id, ObjectId):
        issue_id = ObjectId(issue_id)

    clean_embedding = np.array(embedding).flatten().tolist()

    db["complaints"].update_one(
        {"_id": issue_id},
        {"$push": {"embeddings": clean_embedding}}
    )