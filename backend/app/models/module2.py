from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Numeric, Date
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base

# Модуль 2: Результати Роботи

class WorkResult(Base):
    """Результати роботи (загальна таблиця)"""
    __tablename__ = "work_results"
    
    id = Column(Integer, primary_key=True, index=True)
    employee_id = Column(Integer, ForeignKey("employees.id"), nullable=False)
    organizational_unit_id = Column(Integer, ForeignKey("organizational_units.id"), nullable=False)
    result_date = Column(Date, nullable=False)
    result_type = Column(String(20), nullable=False)  # hours, minutes, pieces, tasks, shifts
    value = Column(Numeric(12, 2), nullable=False)
    unit = Column(String(20), nullable=False)
    status = Column(String(20), default="draft", nullable=False)  # draft, confirmed, cancelled
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    created_by = Column(String(100), nullable=False)
    
    # Relationships
    employee = relationship("Employee", back_populates="work_results")


class Timesheet(Base):
    """Табель обліку робочого часу"""
    __tablename__ = "timesheets"
    
    id = Column(Integer, primary_key=True, index=True)
    employee_id = Column(Integer, ForeignKey("employees.id"), nullable=False)
    organizational_unit_id = Column(Integer, ForeignKey("organizational_units.id"), nullable=False)
    work_date = Column(Date, nullable=False)
    hours_worked = Column(Integer, nullable=False)
    minutes_worked = Column(Integer, default=0, nullable=False)
    shift_type = Column(String(20), nullable=True)  # day, night, overtime
    status = Column(String(20), default="draft", nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    employee = relationship("Employee", back_populates="timesheets")


class ProductionResult(Base):
    """Результати виробництва"""
    __tablename__ = "production_results"
    
    id = Column(Integer, primary_key=True, index=True)
    employee_id = Column(Integer, ForeignKey("employees.id"), nullable=False)
    organizational_unit_id = Column(Integer, ForeignKey("organizational_units.id"), nullable=False)
    work_date = Column(Date, nullable=False)
    product_code = Column(String(50), nullable=False)
    quantity = Column(Numeric(12, 2), nullable=False)
    quality_coefficient = Column(Numeric(5, 2), default=1.0, nullable=False)
    status = Column(String(20), default="draft", nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    employee = relationship("Employee", back_populates="production_results")
