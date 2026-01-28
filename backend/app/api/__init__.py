from fastapi import APIRouter
from app.api.endpoints import periods, employees, calculations

api_router = APIRouter()

# Include routers
api_router.include_router(periods.router, prefix="/periods", tags=["periods"])
api_router.include_router(employees.router, prefix="/employees", tags=["employees"])
api_router.include_router(calculations.router, prefix="/calculations", tags=["calculations"])
