from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routes.predict import router as predict_router
from app.database.mongodb import get_database

# Create FastAPI app FIRST
app = FastAPI()

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(predict_router)

# Health check route
@app.get("/health")
def health_check():
    return {"status": "healthy"}

# MongoDB test route
@app.get("/db-test")
def db_test():
    db = get_database()
    return {"collections": db.list_collection_names()}
