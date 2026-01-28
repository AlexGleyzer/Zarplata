from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from datetime import datetime
from app.core.database import get_db
from app.models import (
    CalculationPeriod,
    AccrualDocument,
    AccrualResult,
    CalculationTemplate,
    TemplateRule,
    Employee
)

router = APIRouter()

class CalculationRequest(BaseModel):
    period_id: int
    template_code: str = "MONTHLY_SALARY"

@router.post("/run")
async def run_calculation(
    request: CalculationRequest,
    db: Session = Depends(get_db)
):
    """Запустити розрахунок для періоду"""
    
    # Перевірка періоду
    period = db.get(CalculationPeriod, request.period_id)
    if not period:
        raise HTTPException(status_code=404, detail="Period not found")
    
    if period.status != "draft":
        raise HTTPException(status_code=400, detail="Period must be in draft status")
    
    # Перевірка шаблону
    template = db.query(CalculationTemplate).filter(
        CalculationTemplate.code == request.template_code
    ).first()
    
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")
    
    # Створення документа нарахування
    doc_number = f"ACC-{period.period_code}-001"
    
    # Перевірка чи документ вже існує
    existing_doc = db.query(AccrualDocument).filter(
        AccrualDocument.document_number == doc_number
    ).first()
    
    if existing_doc:
        raise HTTPException(
            status_code=400,
            detail=f"Document {doc_number} already exists for this period"
        )
    
    accrual_doc = AccrualDocument(
        document_number=doc_number,
        period_id=period.id,
        template_id=template.id,
        organizational_unit_id=period.organizational_unit_id,
        employee_id=period.employee_id,
        status="draft",
        calculation_date=datetime.utcnow(),
        created_by="system"
    )
    
    db.add(accrual_doc)
    db.flush()  # Отримати ID документа
    
    # Отримати працівників для розрахунку
    if period.employee_id:
        employees = [db.get(Employee, period.employee_id)]
    elif period.organizational_unit_id:
        employees = db.query(Employee).filter(
            Employee.organizational_unit_id == period.organizational_unit_id,
            Employee.is_active == True
        ).all()
    else:
        employees = db.query(Employee).filter(Employee.is_active == True).all()
    
    # Отримати правила з шаблону в порядку виконання
    template_rules = db.query(TemplateRule).filter(
        TemplateRule.template_id == template.id,
        TemplateRule.is_active == True
    ).order_by(TemplateRule.execution_order).all()
    
    results_count = 0
    
    # Виконати розрахунок для кожного працівника
    for employee in employees:
        # Виконати правила послідовно
        for template_rule in template_rules:
            rule = template_rule.rule
            
            # Спрощений розрахунок (для MVP)
            # В реальності тут буде виконання SQL з правила
            if rule.code == "BASE_SALARY":
                # Отримати активний контракт
                contract = next(
                    (c for c in employee.contracts if c.is_active and c.contract_type == 'salary'),
                    None
                )
                if contract:
                    result = AccrualResult(
                        document_id=accrual_doc.id,
                        employee_id=employee.id,
                        rule_id=rule.id,
                        rule_code=rule.code,
                        amount=contract.base_rate,
                        calculation_base=contract.base_rate,
                        currency="UAH",
                        status="active"
                    )
                    db.add(result)
                    results_count += 1
            
            elif rule.code == "PIT":
                # Знайти BASE_SALARY для цього працівника в поточному документі
                base_salary = db.query(AccrualResult).filter(
                    AccrualResult.document_id == accrual_doc.id,
                    AccrualResult.employee_id == employee.id,
                    AccrualResult.rule_code == "BASE_SALARY",
                    AccrualResult.status == "active"
                ).first()
                
                if base_salary:
                    pit_amount = base_salary.amount * 0.18
                    result = AccrualResult(
                        document_id=accrual_doc.id,
                        employee_id=employee.id,
                        rule_id=rule.id,
                        rule_code=rule.code,
                        amount=-pit_amount,  # Утримання - негативне
                        calculation_base=base_salary.amount,
                        currency="UAH",
                        status="active"
                    )
                    db.add(result)
                    results_count += 1
            
            elif rule.code == "WAR_TAX":
                # Знайти BASE_SALARY для цього працівника
                base_salary = db.query(AccrualResult).filter(
                    AccrualResult.document_id == accrual_doc.id,
                    AccrualResult.employee_id == employee.id,
                    AccrualResult.rule_code == "BASE_SALARY",
                    AccrualResult.status == "active"
                ).first()
                
                if base_salary:
                    war_tax_amount = base_salary.amount * 0.015
                    result = AccrualResult(
                        document_id=accrual_doc.id,
                        employee_id=employee.id,
                        rule_id=rule.id,
                        rule_code=rule.code,
                        amount=-war_tax_amount,  # Утримання - негативне
                        calculation_base=base_salary.amount,
                        currency="UAH",
                        status="active"
                    )
                    db.add(result)
                    results_count += 1
    
    db.commit()
    db.refresh(accrual_doc)
    
    return {
        "document_id": accrual_doc.id,
        "document_number": accrual_doc.document_number,
        "status": accrual_doc.status,
        "employees_processed": len(employees),
        "results_created": results_count,
        "message": "Calculation completed successfully"
    }

@router.get("/{document_id}")
async def get_calculation_results(
    document_id: int,
    db: Session = Depends(get_db)
):
    """Отримати результати розрахунку"""
    
    document = db.get(AccrualDocument, document_id)
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
    
    # Групувати результати по працівниках
    results_by_employee = {}
    for result in document.accrual_results:
        if result.employee_id not in results_by_employee:
            results_by_employee[result.employee_id] = {
                "employee": {
                    "id": result.employee.id,
                    "name": f"{result.employee.first_name} {result.employee.last_name}",
                    "personnel_number": result.employee.personnel_number
                },
                "results": [],
                "total": 0
            }
        
        results_by_employee[result.employee_id]["results"].append({
            "rule_code": result.rule_code,
            "rule_name": result.rule.name,
            "amount": float(result.amount),
            "calculation_base": float(result.calculation_base) if result.calculation_base else None,
            "status": result.status
        })
        
        results_by_employee[result.employee_id]["total"] += float(result.amount)
    
    return {
        "document_id": document.id,
        "document_number": document.document_number,
        "period": {
            "code": document.period.period_code,
            "name": document.period.period_name
        },
        "template": {
            "code": document.template.code,
            "name": document.template.name
        },
        "status": document.status,
        "calculation_date": document.calculation_date.isoformat() if document.calculation_date else None,
        "employees": list(results_by_employee.values())
    }
