import os
from typing import Optional

import cloudinary
import cloudinary.uploader


_CLOUDINARY_CONFIGURED = False


def _configure_cloudinary() -> None:
    global _CLOUDINARY_CONFIGURED
    if _CLOUDINARY_CONFIGURED:
        return

    cloudinary_url = os.getenv("CLOUDINARY_URL", "").strip()
    cloud_name = os.getenv("CLOUDINARY_CLOUD_NAME", "").strip()
    api_key = os.getenv("CLOUDINARY_API_KEY", "").strip()
    api_secret = os.getenv("CLOUDINARY_API_SECRET", "").strip()

    if cloudinary_url:
        cloudinary.config(cloudinary_url=cloudinary_url, secure=True)
        _CLOUDINARY_CONFIGURED = True
        return

    if cloud_name and api_key and api_secret:
        cloudinary.config(
            cloud_name=cloud_name,
            api_key=api_key,
            api_secret=api_secret,
            secure=True,
        )
        _CLOUDINARY_CONFIGURED = True


def is_cloudinary_enabled() -> bool:
    _configure_cloudinary()
    return _CLOUDINARY_CONFIGURED


def upload_complaint_image(local_file_path: str, complaint_id: str) -> Optional[str]:
    _configure_cloudinary()
    if not _CLOUDINARY_CONFIGURED:
        return None

    result = cloudinary.uploader.upload(
        local_file_path,
        folder="civic-issues",
        public_id=complaint_id,
        overwrite=True,
        resource_type="image",
    )
    return result.get("secure_url")
