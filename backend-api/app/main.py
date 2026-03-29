from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from app.routes.predict import router as predict_router
from app.database.mongodb import get_database
import logging
import time

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("uvicorn")

# Create FastAPI app FIRST
app = FastAPI()

# Custom middleware for logging only /predict API calls
@app.middleware("http")
async def log_predict_requests(request: Request, call_next):
    # Get client info
    client_host = request.client.host if request.client else "unknown"
    client_port = request.client.port if request.client else "unknown"
    
    # Store start time
    start_time = time.time()
    
    # Process the request
    response = await call_next(request)
    
    # Calculate processing time
    process_time = time.time() - start_time
    
    # Only log /predict POST requests
    if request.url.path == "/predict" and request.method == "POST":
        log_message = f'INFO:     {client_host}:{client_port} - "{request.method} {request.url.path} HTTP/1.1" {response.status_code} OK'
        logger.info(log_message)
    
    return response

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
