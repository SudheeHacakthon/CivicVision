def generate_complaint_letter(category: str, location: str) -> str:
    letter = f"Complaint Category: {category}\nLocation: {location}\n\nDear Authorities,\n\nI am writing to report an issue in the infrastructure.\n\nSincerely,\nCitizen"
    return letter
