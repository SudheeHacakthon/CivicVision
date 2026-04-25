from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

class AdminSignup(BaseModel):
    password: str = Field(..., min_length=12)

class AdminLogin(BaseModel):
    email: EmailStr
    password: str

class UserSignup(BaseModel):
    name: str
    email: EmailStr
    phone: str
    password: str = Field(..., min_length=8)
    location: str
    emergency_contact: Optional[str] = None

class Login(BaseModel):
    email: EmailStr
    password: str

class ForgotPasswordRequest(BaseModel):
    email: EmailStr

class OtpVerify(BaseModel):
    email: EmailStr
    otp: str

class ResetPassword(BaseModel):
    email: EmailStr
    otp: str
    new_password: str = Field(..., min_length=8)

class Token(BaseModel):
    access_token: str
    token_type: str

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)

def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)

