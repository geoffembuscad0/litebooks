from fastapi import FastAPI

app = FastAPI(
    title="SimpleBooks API",
    description="Inventory and Accounting Management System",
    version="0.1.0",
)


@app.get("/")
def root():
    return {
        "message": "Welcome to SimpleBooks API",
        "status": "running",
    }


@app.get("/health")
def health_check():
    return {"status": "healthy"}
