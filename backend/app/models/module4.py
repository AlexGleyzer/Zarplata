from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Numeric, Date, Text, JSON
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base

# Модуль 4: Платежі

class PaymentRule(Base):
    """Правила формування платежів"""
    __tablename__ = "payment_rules"
    
    id = Column(Integer, primary_key=True, index=True)
    code = Column(String(50), unique=True, nullable=False, index=True)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    rule_type = Column(String(30), nullable=False)  # individual, grouped, bank_statement
    grouping_logic = Column(JSON, nullable=True)  # JSON з логікою групування
    recipient_type = Column(String(30), nullable=False)  # employee_card, tax_authority, bank_special
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    payment_documents = relationship("PaymentDocument", back_populates="payment_rule")


class PaymentDocument(Base):
    """Документи платежів"""
    __tablename__ = "payment_documents"
    
    id = Column(Integer, primary_key=True, index=True)
    document_number = Column(String(50), unique=True, nullable=False, index=True)
    period_id = Column(Integer, ForeignKey("calculation_periods.id"), nullable=False)
    payment_rule_id = Column(Integer, ForeignKey("payment_rules.id"), nullable=False)
    organizational_unit_id = Column(Integer, ForeignKey("organizational_units.id"), nullable=True)
    employee_id = Column(Integer, ForeignKey("employees.id"), nullable=True)
    total_amount = Column(Numeric(12, 2), nullable=False)
    currency = Column(String(3), default="UAH", nullable=False)
    payment_date = Column(Date, nullable=True)  # планована дата
    actual_payment_date = Column(Date, nullable=True)  # фактична дата
    status = Column(String(20), default="draft", nullable=False)  # draft, in_review, approved, executed, cancelled
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    created_by = Column(String(100), nullable=False)
    approved_by = Column(String(100), nullable=True)
    executed_by = Column(String(100), nullable=True)
    
    # Relationships
    period = relationship("CalculationPeriod", back_populates="payment_documents")
    payment_rule = relationship("PaymentRule", back_populates="payment_documents")
    organizational_unit = relationship("OrganizationalUnit")
    employee = relationship("Employee")
    payment_items = relationship("PaymentItem", back_populates="payment_document")
    bank_statements = relationship("BankStatement", back_populates="payment_document")


class PaymentItem(Base):
    """Позиції платежів"""
    __tablename__ = "payment_items"
    
    id = Column(Integer, primary_key=True, index=True)
    payment_document_id = Column(Integer, ForeignKey("payment_documents.id"), nullable=False)
    accrual_result_id = Column(Integer, ForeignKey("accrual_results.id"), nullable=False)
    employee_id = Column(Integer, ForeignKey("employees.id"), nullable=False)
    amount = Column(Numeric(12, 2), nullable=False)
    currency = Column(String(3), default="UAH", nullable=False)
    recipient_account = Column(String(100), nullable=True)
    purpose = Column(Text, nullable=True)
    status = Column(String(20), default="pending", nullable=False)  # pending, executed, cancelled
    
    # Relationships
    payment_document = relationship("PaymentDocument", back_populates="payment_items")
    accrual_result = relationship("AccrualResult", back_populates="payment_items")
    employee = relationship("Employee")


class BankStatement(Base):
    """Банківські відомості"""
    __tablename__ = "bank_statements"
    
    id = Column(Integer, primary_key=True, index=True)
    payment_document_id = Column(Integer, ForeignKey("payment_documents.id"), nullable=False)
    statement_number = Column(String(50), nullable=False)
    file_path = Column(String(500), nullable=True)
    bank_code = Column(String(20), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    payment_document = relationship("PaymentDocument", back_populates="bank_statements")
