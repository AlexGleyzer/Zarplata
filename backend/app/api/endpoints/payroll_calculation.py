from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Dict, Any
from decimal import Decimal
from datetime import datetime

from app.core.database import get_db
from app.models import (
    Employee, Position, Contract, Group, PositionGroup,
    CalculationRule, OrganizationalUnit
)

router = APIRouter(prefix="/payroll", tags=["payroll"])


def find_applicable_rule(
    position_id: int,
    rule_code: str,
    calculation_date: datetime,
    db: Session
) -> Dict[str, Any]:
    """
    Знайти правило за 4-рівневою ієрархією:
    1. POSITION (персональне)
    2. GROUP (групи працівника)
    3. ORG_UNIT (підрозділ)
    4. GLOBAL (загальне)
    """
    
    position = db.query(Position).filter(Position.id == position_id).first()
    if not position:
        return None
    
    # Рівень 1: POSITION
    rule = db.query(CalculationRule).filter(
        CalculationRule.position_id == position_id,
        CalculationRule.code == rule_code,
        CalculationRule.is_active == True,
        CalculationRule.valid_from <= calculation_date,
        (CalculationRule.valid_until.is_(None) | (CalculationRule.valid_until >= calculation_date))
    ).first()
    
    if rule:
        return {
            "rule": rule,
            "level": "POSITION",
            "source": f"Position {position.position_code}"
        }
    
    # Рівень 2: GROUP
    position_groups = db.query(PositionGroup).filter(
        PositionGroup.position_id == position_id,
        PositionGroup.is_active == True,
        PositionGroup.valid_from <= calculation_date,
        (PositionGroup.valid_until.is_(None) | (PositionGroup.valid_until >= calculation_date))
    ).all()
    
    for pg in position_groups:
        rule = db.query(CalculationRule).filter(
            CalculationRule.group_id == pg.group_id,
            CalculationRule.code == rule_code,
            CalculationRule.is_active == True,
            CalculationRule.valid_from <= calculation_date,
            (CalculationRule.valid_until.is_(None) | (CalculationRule.valid_until >= calculation_date))
        ).first()
        
        if rule:
            group = db.query(Group).filter(Group.id == pg.group_id).first()
            return {
                "rule": rule,
                "level": "GROUP",
                "source": f"Group {group.name}"
            }
    
    # Рівень 3: ORG_UNIT
    rule = db.query(CalculationRule).filter(
        CalculationRule.organizational_unit_id == position.organizational_unit_id,
        CalculationRule.code == rule_code,
        CalculationRule.is_active == True,
        CalculationRule.valid_from <= calculation_date,
        (CalculationRule.valid_until.is_(None) | (CalculationRule.valid_until >= calculation_date))
    ).first()
    
    if rule:
        org_unit = db.query(OrganizationalUnit).filter(
            OrganizationalUnit.id == position.organizational_unit_id
        ).first()
        return {
            "rule": rule,
            "level": "ORG_UNIT",
            "source": f"Org Unit {org_unit.name}"
        }
    
    # Рівень 4: GLOBAL
    rule = db.query(CalculationRule).filter(
        CalculationRule.position_id.is_(None),
        CalculationRule.organizational_unit_id.is_(None),
        CalculationRule.group_id.is_(None),
        CalculationRule.code == rule_code,
        CalculationRule.is_active == True,
        CalculationRule.valid_from <= calculation_date,
        (CalculationRule.valid_until.is_(None) | (CalculationRule.valid_until >= calculation_date))
    ).first()
    
    if rule:
        return {
            "rule": rule,
            "level": "GLOBAL",
            "source": "Global rule"
        }
    
    return None


def calculate_rule(base_salary: Decimal, rule: CalculationRule) -> Decimal:
    """
    Виконати формулу правила
    """
    try:
        # Створити локальний контекст для eval
        context = {
            'base_salary': float(base_salary)
        }
        
        # Виконати формулу
        result = eval(rule.sql_code, {"__builtins__": {}}, context)
        return Decimal(str(result))
    except Exception as e:
        raise ValueError(f"Error calculating rule {rule.code}: {str(e)}")


@router.get("/calculate/{employee_id}")
def calculate_payroll(
    employee_id: int,
    calculation_date: str = "2024-01-15",
    db: Session = Depends(get_db)
):
    """
    Розрахувати зарплату для працівника
    """
    
    # Конвертувати дату
    calc_date = datetime.fromisoformat(calculation_date)
    
    # Знайти працівника
    employee = db.query(Employee).filter(Employee.id == employee_id).first()
    if not employee:
        raise HTTPException(status_code=404, detail="Employee not found")
    
    # Знайти активні позиції
    positions = db.query(Position).filter(
        Position.employee_id == employee_id,
        Position.is_active == True,
        Position.start_date <= calc_date.date(),
        (Position.end_date.is_(None) | (Position.end_date >= calc_date.date()))
    ).all()
    
    if not positions:
        raise HTTPException(status_code=404, detail="No active positions found")
    
    results = []
    
    for position in positions:
        # Знайти контракт
        contract = db.query(Contract).filter(
            Contract.position_id == position.id,
            Contract.is_active == True
        ).first()
        
        if not contract:
            continue
        
        # Базовий оклад з урахуванням ставки
        base_salary = contract.base_rate * position.employment_rate
        
        # Знайти всі правила що застосовуються
        rule_codes = ['PIT', 'MIL_TAX', 'ESV', 'IT_BONUS', 'CLASS_BONUS', 
                      'YOUNG_BONUS', 'DEPUTY_BONUS', 'PERSONAL_BONUS', 
                      'SOCIAL_BENEFIT', 'UNION_FEE']
        
        accruals = []  # Нарахування
        deductions = []  # Утримання
        taxes = []  # Податки
        
        gross_salary = base_salary
        
        for rule_code in rule_codes:
            found = find_applicable_rule(position.id, rule_code, calc_date, db)
            
            if found:
                rule = found['rule']
                amount = calculate_rule(base_salary, rule)
                
                item = {
                    "code": rule.code,
                    "name": rule.name,
                    "type": rule.rule_type,
                    "level": found['level'],
                    "source": found['source'],
                    "formula": rule.sql_code,
                    "amount": float(amount)
                }
                
                if rule.rule_type == 'accrual' or rule.rule_type == 'benefit':
                    accruals.append(item)
                    gross_salary += amount
                elif rule.rule_type == 'deduction':
                    deductions.append(item)
                elif rule.rule_type == 'tax':
                    taxes.append(item)
        
        # Обчислити податки від gross_salary
        total_tax = Decimal(0)
        for tax in taxes:
            # Перерахувати податки від gross_salary
            tax_rule = find_applicable_rule(position.id, tax['code'], calc_date, db)
            if tax_rule:
                tax_amount = calculate_rule(gross_salary, tax_rule['rule'])
                tax['amount'] = float(tax_amount)
                total_tax += tax_amount
        
        # Обчислити утримання
        total_deductions = sum(Decimal(str(d['amount'])) for d in deductions)
        
        # Нетто зарплата
        net_salary = gross_salary - total_tax - total_deductions
        
        results.append({
            "position": {
                "id": position.id,
                "code": position.position_code,
                "name": position.position_name,
                "employment_rate": float(position.employment_rate)
            },
            "base_salary": float(base_salary),
            "accruals": accruals,
            "gross_salary": float(gross_salary),
            "taxes": taxes,
            "deductions": deductions,
            "total_tax": float(total_tax),
            "total_deductions": float(total_deductions),
            "net_salary": float(net_salary)
        })
    
    return {
        "employee": {
            "id": employee.id,
            "personnel_number": employee.personnel_number,
            "full_name": f"{employee.first_name} {employee.last_name}"
        },
        "calculation_date": calculation_date,
        "positions": results
    }


@router.get("/calculate-all")
def calculate_all_employees(
    calculation_date: str = "2024-01-15",
    db: Session = Depends(get_db)
):
    """
    Розрахувати зарплату для всіх працівників
    """
    employees = db.query(Employee).filter(Employee.is_active == True).all()
    
    results = []
    for emp in employees:
        try:
            calc = calculate_payroll(emp.id, calculation_date, db)
            results.append(calc)
        except Exception as e:
            results.append({
                "employee": {
                    "id": emp.id,
                    "personnel_number": emp.personnel_number,
                    "full_name": f"{emp.first_name} {emp.last_name}"
                },
                "error": str(e)
            })
    
    return {
        "calculation_date": calculation_date,
        "total_employees": len(employees),
        "results": results
    }