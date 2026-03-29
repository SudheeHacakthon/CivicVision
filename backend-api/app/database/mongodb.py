import os
from pymongo import MongoClient
from dotenv import load_dotenv

load_dotenv()

MONGO_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
DB_NAME = os.getenv("DB_NAME", "civic_complaints")
_client = None
_db = None

def get_database():
    global _client, _db
    if _client is None:
        try:
            _client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)
            _client.admin.command('ping')
        except:
            print("Atlas unavailable, using in-memory dict as fallback")
            class MockDB:
                def __init__(self):
                    self.complaints = []
                def insert_one(self, data):
                    self.complaints.append(data)
                def find(self, *args, **kwargs):
                    return iter(self.complaints)
                def count_documents(self, *args, **kwargs):
                    return len(self.complaints)
                def find_one(self, *args, **kwargs):
                    for doc in self.complaints:
                        if doc.get("complaint_id") == args[0].get("complaint_id"):
                            return doc
                    return None
                def update_one(self, *args, **kwargs):
                    return type('obj', (object,), {'matched_count': 1})()
                def aggregate(self, pipeline):
                    return []
            _db = MockDB()
            return _db
        _db = _client[DB_NAME]
    return _db
