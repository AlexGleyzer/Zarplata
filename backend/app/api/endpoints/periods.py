from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from datetime import date
from typing import Optional
from app.core.database import get_db
from app.models import CalculationPeriod, OrganizationalUnit, Employee

router = APIRouter()

class PeriodCreate(BaseModel):
    period_code: str
    period_name: str
    start_date: date
    end_date: date
    period_type: str = "monthly"
    organizational_unit_id: Optional[int] = None
    employee_id: Optional[int] = None

@router.get("/")
async def get_periods(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db)
):
    """Отримати список періодів"""
    periods = db.query(CalculationPeriod).offset(skip).limit(limit).all()
    
    return {
        "total": db.query(CalculationPeriod).count(),
        "items": [
            {
                "id": period.id,
                "period_code": period.period_code,
                "period_name": period.period_name,
                "start_date": period.start_date.isoformat(),
                "end_date": period.end_date.isoformat(),
                "period_type": period.period_type,
                "status": period.status,
                "created_by": period.created_by
            }
            for period in periods
        ]
    }

@router.post("/")
async def create_period(
    period: PeriodCreate,
    db: Session = Depends(get_db)
):
    """Створити новий розрахунковий період"""
    
    # Перевірка чи період з таким кодом вже існує
    existing = db.query(CalculationPeriod).filter(
        CalculationPeriod.period_code == period.period_code
    ).first()
    
    if existing:
        raise HTTPException(status_code=400, detail="Period with this code already exists")
    
    # Створення нового періоду
    new_period = CalculationPeriod(
        period_code=period.period_code,
        period_name=period.period_name,
        start_date=period.start_date,
        end_date=period.end_date,
        period_type=period.period_type,
        organizational_unit_id=period.organizational_unit_id,
        employee_id=period.employee_id,
        status="draft",
        created_by="system"
    )
    
    db.add(new_period)
    db.commit()
    db.refresh(new_period)
    
    return {
        "id": new_period.id,
        "period_code": new_period.period_code,
        "period_name": new_period.period_name,
        "start_date": new_period.start_date.isoformat(),
        "end_date": new_period.end_date.isoformat(),
        "status": new_period.status,
        "message": "Period created successfully"
    }

@router.get("/{period_id}")
async def get_period(
    period_id: int,
    db: Session = Depends(get_db)
):
    """Отримати деталі періоду"""
    period = db.get(CalculationPeriod, period_id)
    if not period:
        raise HTTPException(status_code=404, detail="Period not found")
    
    return {
        "id": period.id,
        "period_code": period.period_code,
        "period_name": period.period_name,
        "start_date": period.start_date.isoformat(),
        "end_date": period.end_date.isoformat(),
        "period_type": period.period_type,
        "status": period.status,
        "organizational_unit_id": period.organizational_unit_id,
        "employee_id": period.employee_id,
        "created_by": period.created_by,
        "accrual_documents": [
            {
                "id": doc.id,
                "document_number": doc.document_number,
                "status": doc.status
            }
            for doc in period.accrual_documents
        ]
    }
