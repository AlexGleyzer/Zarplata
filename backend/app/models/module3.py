from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Numeric, Text, Date, CheckConstraint
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from sqlalchemy.dialects.postgresql import JSONB
from app.core.database import Base


class CalculationPeriod(Base):
    __tablename__ = "calculation_periods"
    
    id = Column(Integer, primary_key=True)
    
    # Ідентифікація
    period_code = Column(String(50), nullable=False, index=True)
    period_name = Column(String(255), nullable=False)
    
    # Дати періоду
    start_date = Column(Date, nullable=False, index=True)
    end_date = Column(Date, nullable=False, index=True)
    
    # Тип періоду
    period_type = Column(String(20), nullable=False)
    
    # Scope
    organizational_unit_id = Column(Integer, ForeignKey("organizational_units.id"), index=True)
    employee_id = Column(Integer, ForeignKey("employees.id"), index=True)
    
    # Статус
    status = Column(String(20), default="draft", nullable=False, index=True)
    
    # Метадані
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    created_by = Column(String(100), nullable=False)
    
    # Relationships
    organizational_unit = relationship("OrganizationalUnit")
    employee = relationship("Employee")
    accrual_documents = relationship("AccrualDocument", back_populates="period")
    payment_documents = relationship("PaymentDocument", back_populates="period")
    
    def __repr__(self):
        return f"<CalculationPeriod(id={self.id}, code='{self.period_code}')>"


class AccrualDocument(Base):
    __tablename__ = "accrual_documents"
    
    id = Column(Integer, primary_key=True)
    
    # Ідентифікація
    document_number = Column(String(50), unique=True, nullable=False, index=True)
    
    # Зв'язки
    period_id = Column(Integer, ForeignKey("calculation_periods.id"), nullable=False, index=True)
    template_id = Column(Integer, ForeignKey("calculation_templates.id"), nullable=False, index=True)
    organizational_unit_id = Column(Integer, ForeignKey("organizational_units.id"), index=True)
    employee_id = Column(Integer, ForeignKey("employees.id"), index=True)
    
    # Статус
    status = Column(String(20), default="draft", nullable=False, index=True)
    
    # Workflow
    calculation_date = Column(DateTime(timezone=True))
    approved_date = Column(DateTime(timezone=True))
    approved_by = Column(String(100))
    cancelled_date = Column(DateTime(timezone=True))
    cancelled_by = Column(String(100))
    
    # Метадані
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    created_by = Column(String(100), nullable=False)
    
    # Relationships
    period = relationship("CalculationPeriod", back_populates="accrual_documents")
    template = relationship("CalculationTemplate", back_populates="accrual_documents")
    organizational_unit = relationship("OrganizationalUnit")
    employee = relationship("Employee")
    results = relationship("AccrualResult", back_populates="document", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<AccrualDocument(id={self.id}, number='{self.document_number}')>"


class AccrualResult(Base):
    __tablename__ = "accrual_results"
    
    id = Column(Integer, primary_key=True)
    
    # Зв'язки
    document_id = Column(Integer, ForeignKey("accrual_documents.id", ondelete="CASCADE"), nullable=False, index=True)
    position_id = Column(Integer, ForeignKey("positions.id"), index=True)  # НОВЕ!
    employee_id = Column(Integer, ForeignKey("employees.id"), nullable=False, index=True)
    organizational_unit_id = Column(Integer, ForeignKey("organizational_units.id"), index=True)  # НОВЕ!
    
    # Правило
    rule_id = Column(Integer, ForeignKey("calculation_rules.id"), nullable=False, index=True)
    rule_code = Column(String(50), nullable=False, index=True)
    
    # Джерело правила (для аудиту) - НОВЕ!
    rule_source_type = Column(String(20), index=True)  # position, group, organizational_unit, global
    rule_source_id = Column(Integer, index=True)
    
    # Результат
    amount = Column(Numeric(12, 2), nullable=False)
    calculation_base = Column(Numeric(12, 2))  # НОВЕ!
    currency = Column(String(3), default="UAH", nullable=False)
    
    # Статус
    status = Column(String(20), default="active", nullable=False, index=True)
    
    # Метадані
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    notes = Column(Text)
    
    # Relationships
    document = relationship("AccrualDocument", back_populates="results")
    position = relationship("Position", back_populates="accrual_results")  # НОВЕ!
    employee = relationship("Employee")
    organizational_unit = relationship("OrganizationalUnit")
    rule = relationship("CalculationRule")
    payment_items = relationship("PaymentItem", back_populates="accrual_result")
    
    def __repr__(self):
        return f"<AccrualResult(id={self.id}, rule_code='{self.rule_code}', amount={self.amount})>"


class ChangeRequest(Base):
    __tablename__ = "change_requests"
    
    id = Column(Integer, primary_key=True)
    
    # Зв'язки
    document_id = Column(Integer, ForeignKey("accrual_documents.id"), nullable=False, index=True)
    employee_id = Column(Integer, ForeignKey("employees.id"), nullable=False, index=True)
    
    # Тип зміни
    change_type = Column(String(50), nullable=False)
    
    # Дані зміни
    old_value = Column(JSONB)
    new_value = Column(JSONB)
    
    # Обґрунтування
    reason = Column(Text, nullable=False)
    supporting_documents = Column(Text)
    
    # Статус
    status = Column(String(20), default="pending", nullable=False, index=True)
    
    # Workflow
    requested_at = Column(DateTime(timezone=True), server_default=func.now())
    requested_by = Column(String(100), nullable=False)
    reviewed_at = Column(DateTime(timezone=True))
    reviewed_by = Column(String(100))
    review_comment = Column(Text)
    
    # Relationships
    document = relationship("AccrualDocument")
    employee = relationship("Employee")
    
    def __repr__(self):
        return f"<ChangeRequest(id={self.id}, type='{self.change_type}', status='{self.status}')>"


class SplitReason(Base):
    __tablename__ = "split_reasons"
    
    code = Column(String(50), primary_key=True)
    name = Column(String(255), nullable=False)
    description = Column(Text)
    auto_split = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    def __repr__(self):
        return f"<SplitReason(code='{self.code}', name='{self.name}')>"