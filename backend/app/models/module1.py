from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Numeric, Text, Date
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base

# Модуль 1: Структура Підприємства і Працівники

class OrganizationalUnit(Base):
    """Організаційна структура"""
    __tablename__ = "organizational_units"
    
    id = Column(Integer, primary_key=True, index=True)
    parent_id = Column(Integer, ForeignKey("organizational_units.id"), nullable=True)
    code = Column(String(50), unique=True, nullable=False, index=True)
    name = Column(String(255), nullable=False)
    level = Column(Integer, nullable=False)  # 1-6
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    parent = relationship("OrganizationalUnit", remote_side=[id], backref="children")
    employees = relationship("Employee", back_populates="organizational_unit")
    contracts = relationship("Contract", back_populates="organizational_unit")
    calculation_rules = relationship("CalculationRule", back_populates="organizational_unit")


class Employee(Base):
    """Працівники"""
    __tablename__ = "employees"
    
    id = Column(Integer, primary_key=True, index=True)
    organizational_unit_id = Column(Integer, ForeignKey("organizational_units.id"), nullable=False)
    personnel_number = Column(String(20), unique=True, nullable=False, index=True)
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    middle_name = Column(String(100), nullable=True)
    hire_date = Column(Date, nullable=False)
    termination_date = Column(Date, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    organizational_unit = relationship("OrganizationalUnit", back_populates="employees")
    contracts = relationship("Contract", back_populates="employee")
    work_results = relationship("WorkResult", back_populates="employee")
    timesheets = relationship("Timesheet", back_populates="employee")
    production_results = relationship("ProductionResult", back_populates="employee")
    accrual_results = relationship("AccrualResult", back_populates="employee")


class Contract(Base):
    """Контракти працівників"""
    __tablename__ = "contracts"
    
    id = Column(Integer, primary_key=True, index=True)
    employee_id = Column(Integer, ForeignKey("employees.id"), nullable=False)
    organizational_unit_id = Column(Integer, ForeignKey("organizational_units.id"), nullable=False)
    contract_number = Column(String(50), unique=True, nullable=False)
    contract_type = Column(String(20), nullable=False)  # hourly, salary, piecework, task_based
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=True)
    base_rate = Column(Numeric(12, 2), nullable=False)
    currency = Column(String(3), default="UAH", nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    employee = relationship("Employee", back_populates="contracts")
    organizational_unit = relationship("OrganizationalUnit", back_populates="contracts")


class CalculationRule(Base):
    """Правила нарахувань з SQL кодом"""
    __tablename__ = "calculation_rules"
    
    id = Column(Integer, primary_key=True, index=True)
    organizational_unit_id = Column(Integer, ForeignKey("organizational_units.id"), nullable=True)
    code = Column(String(50), unique=True, nullable=False, index=True)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    sql_code = Column(Text, nullable=False)
    rule_type = Column(String(20), nullable=False)  # accrual, deduction, tax
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    created_by = Column(String(100), nullable=False)
    
    # Relationships
    organizational_unit = relationship("OrganizationalUnit", back_populates="calculation_rules")
    template_rules = relationship("TemplateRule", back_populates="rule")
    accrual_results = relationship("AccrualResult", back_populates="rule")


class CalculationTemplate(Base):
    """Шаблони розрахунків"""
    __tablename__ = "calculation_templates"
    
    id = Column(Integer, primary_key=True, index=True)
    code = Column(String(50), unique=True, nullable=False, index=True)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    template_rules = relationship("TemplateRule", back_populates="template", order_by="TemplateRule.execution_order")
    accrual_documents = relationship("AccrualDocument", back_populates="template")


class TemplateRule(Base):
    """Зв'язок шаблонів і правил з порядком виконання"""
    __tablename__ = "template_rules"
    
    id = Column(Integer, primary_key=True, index=True)
    template_id = Column(Integer, ForeignKey("calculation_templates.id"), nullable=False)
    rule_id = Column(Integer, ForeignKey("calculation_rules.id"), nullable=False)
    execution_order = Column(Integer, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    
    # Relationships
    template = relationship("CalculationTemplate", back_populates="template_rules")
    rule = relationship("CalculationRule", back_populates="template_rules")
