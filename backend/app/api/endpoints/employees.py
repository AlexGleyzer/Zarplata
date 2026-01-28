from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.core.database import get_db
from app.models import Employee, OrganizationalUnit
from sqlalchemy import select

router = APIRouter()

@router.get("/")
async def get_employees(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db)
):
    """Отримати список працівників"""
    employees = db.execute(
        select(Employee)
        .offset(skip)
        .limit(limit)
    ).scalars().all()
    
    return {
        "total": db.query(Employee).count(),
        "items": [
            {
                "id": emp.id,
                "personnel_number": emp.personnel_number,
                "first_name": emp.first_name,
                "last_name": emp.last_name,
                "hire_date": emp.hire_date.isoformat() if emp.hire_date else None,
                "is_active": emp.is_active,
                "organizational_unit": {
                    "id": emp.organizational_unit.id,
                    "name": emp.organizational_unit.name,
                    "code": emp.organizational_unit.code
                } if emp.organizational_unit else None
            }
            for emp in employees
        ]
    }

@router.get("/{employee_id}")
async def get_employee(
    employee_id: int,
    db: Session = Depends(get_db)
):
    """Отримати деталі працівника"""
    employee = db.get(Employee, employee_id)
    if not employee:
        raise HTTPException(status_code=404, detail="Employee not found")
    
    return {
        "id": employee.id,
        "personnel_number": employee.personnel_number,
        "first_name": employee.first_name,
        "last_name": employee.last_name,
        "middle_name": employee.middle_name,
        "hire_date": employee.hire_date.isoformat() if employee.hire_date else None,
        "termination_date": employee.termination_date.isoformat() if employee.termination_date else None,
        "is_active": employee.is_active,
        "organizational_unit": {
            "id": employee.organizational_unit.id,
            "name": employee.organizational_unit.name,
            "code": employee.organizational_unit.code
        } if employee.organizational_unit else None,
        "contracts": [
            {
                "id": contract.id,
                "contract_number": contract.contract_number,
                "contract_type": contract.contract_type,
                "base_rate": float(contract.base_rate),
                "currency": contract.currency,
                "is_active": contract.is_active
            }
            for contract in employee.contracts
        ]
    }
