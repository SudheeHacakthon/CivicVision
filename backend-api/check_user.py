from app.database.mongodb import get_database
import sys

email = "rikku475@gmail.com" # Checking the common user email

db = get_database()
user = db["users"].find_one({"email": email})

if user:
    print(f"User found: {user['email']}")
    print(f"Hashed Password: {user.get('password')}")
else:
    print("User not found in database.")
