import os
from io import BytesIO
from typing import Union

import cloudinary
import cloudinary.uploader
from fastapi import HTTPException
from PIL import Image


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


def upload_complaint_image(
    image_source: Union[bytes, Image.Image],
    complaint_id: str
) -> str:
    """
    Upload image directly to Cloudinary from memory.
    
    Args:
        image_source: Either raw bytes or a PIL Image object
        complaint_id: Unique identifier for the complaint (used as public_id)
    
    Returns:
        The secure_url from Cloudinary
    
    Raises:
        HTTPException: If Cloudinary is not configured or upload fails
    """
    _configure_cloudinary()
    
    if not _CLOUDINARY_CONFIGURED:
        raise HTTPException(
            status_code=503,
            detail="Image upload service is not configured. Please contact support."
        )

    try:
        # Convert PIL Image to bytes if needed
        if hasattr(image_source, 'save'):
            # It's a PIL Image
            buffer = BytesIO()
            image_source.save(buffer, format="JPEG", quality=95, subsampling=0)
            buffer.seek(0)
            image_bytes = buffer.getvalue()
        else:
            # It's already bytes
            image_bytes = image_source

        # Upload directly from memory
        result = cloudinary.uploader.upload(
            image_bytes,
            folder="civic-issues",
            public_id=complaint_id,
            overwrite=True,
            resource_type="image",
        )
        
        secure_url = result.get("secure_url")
        
        if not secure_url:
            raise HTTPException(
                status_code=500,
                detail="Failed to get image URL from upload service"
            )
        
        return secure_url
        
    except HTTPException:
        # Re-raise HTTPExceptions as-is
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Image upload failed: {str(e)}"
        )
