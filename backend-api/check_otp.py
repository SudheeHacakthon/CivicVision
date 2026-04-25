from app.database.mongodb import get_database

email = "rikku475@gmail.com"
db = get_database()
otp = db["otp"].find_one({"email": email})

if otp:
    print(f"OTP doc found for {email}")
    print(f"Verified status: {otp.get('verified')}")
else:
    print("OTP doc not found.")
