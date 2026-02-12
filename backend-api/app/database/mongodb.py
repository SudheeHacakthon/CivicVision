import os
from pymongo import MongoClient
from dotenv import load_dotenv

load_dotenv()

def get_database():
    client = MongoClient(os.getenv("MONGODB_URI"))
    return client["crowdsourced_infra_monitor"]
