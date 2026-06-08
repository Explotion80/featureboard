import os
from fastapi import FastAPI

app = FastAPI()


@app.get("/")
def root():
    return {
        "environment": os.getenv("ENVIRONMENT", "local"),
        "version": os.getenv("APP_VERSION", "0.0.0-dev"),
    }


@app.get("/health")
def health():
    return {"status": "ok"}