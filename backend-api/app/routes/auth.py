from fastapi import APIRouter, HTTPException
from pydantic import EmailStr
from app.schemas.auth import (
    AdminSignup,
    AdminLogin,
    UserSignup,
    OtpVerify,
    Login,
    get_password_hash,
    verify_password,
)
from app.services.email_service import send_otp_email
from app.database.mongodb import get_database
from datetime import datetime, timedelta, UTC
import random
import logging

router = APIRouter(prefix="/auth", tags=["auth"])
logger = logging.getLogger(__name__)

OTP_VALID_MINUTES = 10

# Fixed admin credentials
ADMIN_CREDENTIALS = {
    "rizwik475@gmail.com": "rithwikpro475",
    "priyanshunerella@gmail.com": "anshu123",
    "mjahnavi956@gmail.com": "jahnavi123",
}


def _collection(name: str):
    db = get_database()
    try:
        collection = db[name]
        # Safe to call repeatedly; MongoDB keeps existing indexes.
        if name == "users":
            collection.create_index("email", unique=True)
        if name == "otp":
            collection.create_index("email", unique=True)
        return collection
    except Exception:
        raise HTTPException(status_code=500, detail="MongoDB unavailable for auth storage")


def _find_user(email: str):
    return _collection("users").find_one({"email": email})

@router.post("/admin/signup")
async def admin_signup(admin: AdminSignup):
    # Mock implementation: accept any strong password validated by schema and issue token.
    return {
        "success": True,
        "token": "admin_jwt_mock",
        "role": "admin",
        "email": "rizwik475@gmail.com",
    }

@router.post("/admin/login")
async def admin_login(admin: AdminLogin):
    # Validate against fixed admin credentials
    email = admin.email.strip().lower()
    password = admin.password.strip()
    if email in ADMIN_CREDENTIALS and ADMIN_CREDENTIALS[email] == password:
        return {"success": True, "token": "admin_jwt_mock", "role": "admin", "email": email}
    raise HTTPException(status_code=400, detail="Invalid admin credentials")

@router.post("/user/signup")
async def user_signup(user: UserSignup):
    users = _collection("users")
    otp_col = _collection("otp")

    email = user.email.strip().lower()
    existing_user = _find_user(email)
    existing_otp = otp_col.find_one({"email": email})
    already_verified = bool(existing_otp and existing_otp.get("verified") is True)

    if existing_user and already_verified:
        raise HTTPException(status_code=400, detail="User already exists. Please login")

    otp = ''.join(random.choices('0123456789', k=6))
    now_iso = datetime.now(UTC).isoformat()

    users.update_one(
        {"email": email},
        {
            "$set": {
                "name": user.name.strip(),
                "phone": user.phone.strip(),
                "password": get_password_hash(user.password.strip()),
                "role": "user",
                "location": user.location.strip(),
                "emergency_contact": (user.emergency_contact or "").strip(),
            },
            "$setOnInsert": {
                "email": email,
                "created_at": now_iso,
            },
        },
        upsert=True,
    )

    otp_col.update_one(
        {"email": email},
        {
            "$set": {
                "email": email,
                "otp": otp,
                "expires_at": (datetime.now(UTC) + timedelta(minutes=OTP_VALID_MINUTES)).isoformat(),
                "verified": False,
            }
        },
        upsert=True,
    )

    try:
        send_otp_email(email, otp, OTP_VALID_MINUTES)
    except Exception as exc:
        logger.exception("Failed to send OTP email to %s", email)
        raise HTTPException(status_code=500, detail=f"Failed to send OTP email: {str(exc)}")
    return {"success": True, "message": "OTP sent to email"}


@router.post("/verify-otp")
async def verify_otp(verify: OtpVerify):
    email = verify.email.strip().lower()
    otp_col = _collection("otp")

    stored = otp_col.find_one({"email": email})
    if not stored:
        raise HTTPException(status_code=400, detail="OTP not found. Please request a new OTP")

    expires_at = stored.get("expires_at")
    if not expires_at:
        raise HTTPException(status_code=400, detail="OTP not found. Please request a new OTP")

    try:
        expires_at_dt = datetime.fromisoformat(expires_at)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid OTP state. Please request a new OTP")

    if datetime.now(UTC) > expires_at_dt:
        raise HTTPException(status_code=400, detail="OTP expired. Please request a new OTP")

    if stored.get("otp") != verify.otp:
        raise HTTPException(status_code=400, detail="Invalid OTP")

    otp_col.update_one(
        {"email": email},
        {"$set": {"verified": True}},
    )

    return {
        "success": True,
        "token": "user_jwt_mock",
        "role": "user",
        "email": email,
    }


@router.post("/user/login")
async def user_login(login: Login):
    email = login.email.strip().lower()
    users = _collection("users")
    otp_col = _collection("otp")

    user = users.find_one({"email": email})
    if not user:
        raise HTTPException(status_code=400, detail="Invalid credentials")

    otp_doc = otp_col.find_one({"email": email})
    if not otp_doc or otp_doc.get("verified") is not True:
        raise HTTPException(status_code=400, detail="Email not verified. Please complete OTP signup")

    if not verify_password(login.password.strip(), user.get("password", "")):
        raise HTTPException(status_code=400, detail="Invalid credentials")

    return {
        "success": True,
        "token": "user_jwt_mock",
        "role": "user",
        "email": email,
    }


@router.post("/forgot-password")
async def forgot_password(email: EmailStr):
    otp_col = _collection("otp")
    normalized_email = email.strip().lower()
    otp = ''.join(random.choices('0123456789', k=6))

    otp_col.update_one(
        {"email": normalized_email},
        {
            "$set": {
                "email": normalized_email,
                "otp": otp,
                "expires_at": (datetime.now(UTC) + timedelta(minutes=OTP_VALID_MINUTES)).isoformat(),
                "verified": False,
            }
        },
        upsert=True,
    )

    try:
        send_otp_email(normalized_email, otp, OTP_VALID_MINUTES)
    except Exception as exc:
        logger.exception("Failed to send forgot-password OTP email to %s", normalized_email)
        raise HTTPException(status_code=500, detail=f"Failed to send OTP email: {str(exc)}")
    return {"message": "OTP sent"}
