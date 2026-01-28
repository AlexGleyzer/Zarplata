from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Numeric, Date, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base

# Модуль 3: Періоди та Нарахування

class CalculationPeriod(Base):
    """Розрахункові періоди"""
    __tablename__ = "calculation_periods"
    
    id = Column(Integer, primary_key=True, index=True)
    period_code = Column(String(50), unique=True, nullable=False, index=True)
    period_name = Column(String(255), nullable=False)
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=False)
    period_type = Column(String(20), nullable=False)  # monthly, weekly, custom
    organizational_unit_id = Column(Integer, ForeignKey("organizational_units.id"), nullable=True)
    employee_id = Column(Integer, ForeignKey("employees.id"), nullable=True)
    status = Column(String(20), default="draft", nullable=False)  # draft, in_review, approved, cancelled
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    created_by = Column(String(100), nullable=False)
    
    # Relationships
    accrual_documents = relationship("AccrualDocument", back_populates="period")
    payment_documents = relationship("PaymentDocument", back_populates="period")


class AccrualDocument(Base):
    """Документи нарахувань"""
    __tablename__ = "accrual_documents"
    
    id = Column(Integer, primary_key=True, index=True)
    document_number = Column(String(50), unique=True, nullable=False, index=True)
    period_id = Column(Integer, ForeignKey("calculation_periods.id"), nullable=False)
    template_id = Column(Integer, ForeignKey("calculation_templates.id"), nullable=False)
    organizational_unit_id = Column(Integer, ForeignKey("organizational_units.id"), nullable=True)
    employee_id = Column(Integer, ForeignKey("employees.id"), nullable=True)
    status = Column(String(20), default="draft", nullable=False)  # draft, in_review, approved, cancelled
    calculation_date = Column(DateTime(timezone=True), nullable=True)
    approved_date = Column(DateTime(timezone=True), nullable=True)
    approved_by = Column(String(100), nullable=True)
    cancelled_date = Column(DateTime(timezone=True), nullable=True)
    cancelled_by = Column(String(100), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    created_by = Column(String(100), nullable=False)
    
    # Relationships
    period = relationship("CalculationPeriod", back_populates="accrual_documents")
    template = relationship("CalculationTemplate", back_populates="accrual_documents")
    accrual_results = relationship("AccrualResult", back_populates="document")
    change_requests = relationship("ChangeRequest", back_populates="document")


class AccrualResult(Base):
    """Результати нарахувань (immutable)"""
    __tablename__ = "accrual_results"
    
    id = Column(Integer, primary_key=True, index=True)
    document_id = Column(Integer, ForeignKey("accrual_documents.id"), nullable=False)
    employee_id = Column(Integer, ForeignKey("employees.id"), nullable=False)
    rule_id = Column(Integer, ForeignKey("calculation_rules.id"), nullable=False)
    rule_code = Column(String(50), nullable=False)  # для історії
    amount = Column(Numeric(12, 2), nullable=False)
    calculation_base = Column(Numeric(12, 2), nullable=True)
    currency = Column(String(3), default="UAH", nullable=False)
    status = Column(String(20), default="active", nullable=False)  # active, cancelled
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    document = relationship("AccrualDocument", back_populates="accrual_results")
    employee = relationship("Employee", back_populates="accrual_results")
    rule = relationship("CalculationRule", back_populates="accrual_results")
    payment_items = relationship("PaymentItem", back_populates="accrual_result")


class ChangeRequest(Base):
    """Запити на зміни документів"""
    __tablename__ = "change_requests"
    
    id = Column(Integer, primary_key=True, index=True)
    request_number = Column(String(50), unique=True, nullable=False, index=True)
    document_id = Column(Integer, ForeignKey("accrual_documents.id"), nullable=False)
    reason = Column(Text, nullable=False)
    requested_by = Column(String(100), nullable=False)
    request_date = Column(DateTime(timezone=True), server_default=func.now())
    status = Column(String(20), default="pending", nullable=False)  # pending, approved, rejected
    approved_by = Column(String(100), nullable=True)
    approved_date = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    document = relationship("AccrualDocument", back_populates="change_requests")
