from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import os

from app.api import api_router
from app.core.config import settings

app = FastAPI(
    title="Payroll Management System",
    description="Система управління розрахунком зарплат",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # У продакшені змінити на конкретні домени
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# API Router
app.include_router(api_router, prefix="/api")

# Static Files (для тестової сторінки)
static_path = os.path.join(os.path.dirname(__file__), "static")
if os.path.exists(static_path):
    app.mount("/static", StaticFiles(directory=static_path), name="static")


# Routes
@app.get("/")
async def root():
    """
    Головна сторінка
    """
    return {
        "message": "Payroll Management System API v2.0",
        "docs": "/docs",
        "test_rules": "/test-rules"
    }


@app.get("/health")
async def health_check():
    """
    Перевірка здоров'я сервісу
    """
    return {
        "status": "healthy",
        "version": "2.0.0"
    }


@app.get("/test-rules")
async def test_rules_page():
    """
    Тестова сторінка для перевірки правил розрахунку
    """
    html_path = os.path.join(static_path, "test-rules.html")
    if os.path.exists(html_path):
        return FileResponse(html_path)
    else:
        return {
            "error": "test-rules.html not found",
            "path": html_path
        }


@app.on_event("startup")
async def startup_event():
    """
    Виконується при запуску
    """
    print("Payroll Management System v2.0 started")
    print("API Docs: http://localhost:8000/docs")
    print("Test Rules: http://localhost:8000/test-rules")


@app.on_event("shutdown")
async def shutdown_event():
    """
    Виконується при зупинці
    """
    print("Shutting down...")