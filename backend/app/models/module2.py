from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Numeric, Text, Date, CheckConstraint
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base


class WorkResult(Base):
    __tablename__ = "work_results"
    
    id = Column(Integer, primary_key=True)
    employee_id = Column(Integer, ForeignKey("employees.id"), nullable=False, index=True)
    work_date = Column(Date, nullable=False, index=True)
    work_type = Column(String(50), nullable=False)
    quantity = Column(Numeric(10, 2), nullable=False)
    unit = Column(String(20))
    rate = Column(Numeric(10, 2))
    amount = Column(Numeric(12, 2))
    
    status = Column(String(20), default="draft", nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    created_by = Column(String(100), nullable=False)
    
    employee = relationship("Employee")


class Timesheet(Base):
    __tablename__ = "timesheets"
    
    id = Column(Integer, primary_key=True)
    
    # Зв'язок з позицією
    position_id = Column(Integer, ForeignKey("positions.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Точний час роботи
    work_start = Column(DateTime(timezone=True), nullable=False, index=True)
    work_end = Column(DateTime(timezone=True), nullable=False, index=True)
    
    # Тривалість
    duration_minutes = Column(Integer)
    break_minutes = Column(Integer, default=0, server_default="0")
    overtime_minutes = Column(Integer, default=0, server_default="0")
    
    # Тип зміни
    shift_type = Column(String(20))
    
    # Статус
    status = Column(String(20), default="draft", server_default="'draft'", index=True)
    
    # Метадані
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    created_by = Column(String(100), nullable=False, server_default="'migration_v2'")
    notes = Column(Text)
    
    # Relationships
    position = relationship("Position", back_populates="timesheets")
    
    def __repr__(self):
        return f"<Timesheet(id={self.id}, position_id={self.position_id})>"


class ProductionResult(Base):
    __tablename__ = "production_results"
    
    id = Column(Integer, primary_key=True)
    employee_id = Column(Integer, ForeignKey("employees.id"), nullable=False, index=True)
    production_date = Column(Date, nullable=False, index=True)
    product_code = Column(String(50), nullable=False)
    quantity = Column(Numeric(10, 2), nullable=False)
    unit_price = Column(Numeric(10, 2))
    total_amount = Column(Numeric(12, 2))
    
    status = Column(String(20), default="draft", nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    created_by = Column(String(100), nullable=False)
    
    employee = relationship("Employee")