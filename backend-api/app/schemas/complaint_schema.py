from pydantic import BaseModel

class ComplaintRequest(BaseModel):
    category: str
    location: str

class ComplaintResponse(BaseModel):
    letter: str
