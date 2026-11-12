from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.auth import router as auth_router
from app.api.companies import router as companies_router
from app.api.contacts import router as contacts_router
from app.api.inventory import router as inventory_router
from app.core.config import get_settings

settings = get_settings()

app = FastAPI(
    title="LiteBooks API",
    description="Inventory and Accounting Management System",
    version="0.4.0",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)
app.include_router(auth_router)
app.include_router(companies_router)
app.include_router(inventory_router)
app.include_router(contacts_router)


@app.get("/")
def root():
    return {"message": "Welcome to LiteBooks API", "status": "running"}


@app.get("/health")
def health_check():
    return {"status": "healthy"}
