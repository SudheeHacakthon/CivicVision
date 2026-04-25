import requests

email = "rikku475@gmail.com"
new_password = "password123"

# 1. Reset password manually via direct DB update
from app.database.mongodb import get_database
from app.schemas.auth import get_password_hash

db = get_database()
db["users"].update_one(
    {"email": email},
    {"$set": {"password": get_password_hash(new_password)}}
)
print("Password forced to:", new_password)

# 2. Try to login
login_data = {
    "email": email,
    "password": new_password
}
res = requests.post("http://127.0.0.1:8000/auth/user/login", json=login_data)
print("Login status:", res.status_code)
print("Login response:", res.json())
