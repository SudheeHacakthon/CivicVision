from app.database.mongodb import get_database
from app.schemas.auth import verify_password

email = "rikku475@gmail.com"
db = get_database()
user = db["users"].find_one({"email": email})
otp = db["otp"].find_one({"email": email})

print(f"--- Diagnostic for {email} ---")
if not user:
    print("CRITICAL: User document missing from 'users' collection.")
else:
    print(f"User exists. Role: {user.get('role')}")
    # We can't know the password, but we can verify if the hash is valid format
    pwd_hash = user.get('password', '')
    print(f"Password hash present: {bool(pwd_hash)}")
    print(f"Hash starts with: {pwd_hash[:10]}...")

if not otp:
    print("CRITICAL: OTP document missing from 'otp' collection.")
else:
    print(f"OTP Verified field value: {otp.get('verified')}")
    print(f"OTP Verified field type: {type(otp.get('verified'))}")

# Check if there are ANY other users
all_users = list(db["users"].find({}, {"email": 1}))
print(f"Total users in DB: {len(all_users)}")
for u in all_users:
    print(f" - {u['email']}")
