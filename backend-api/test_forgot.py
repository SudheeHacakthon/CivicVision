import requests

res = requests.post("http://127.0.0.1:8000/auth/forgot-password", json={"email": "rikku475@gmail.com"})
print("Status Code:", res.status_code)
print("Response:", res.text)
