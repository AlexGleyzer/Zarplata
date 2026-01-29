# Модуль 1: Структура Підприємства і Працівники
from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Numeric, Text, Date, Time, CheckConstraint, UniqueConstraint
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from sqlalchemy.dialects.postgresql import JSONB, ARRAY
from app.core.database import Base


class ShiftSchedule(Base):
    __tablename__ = "shift_schedules"
    
    id = Column(Integer, primary_key=True)
    
    # Ідентифікація
    code = Column(String(50), unique=True, nullable=False, index=True)
    name = Column(String(255), nullable=False)
    description = Column(Text)
    
    # Тип графіку
    schedule_type = Column(String(20), nullable=False)  # fixed, rotating, flexible
    
    # Налаштування зміни
    shift_start = Column(Time, nullable=False)
    shift_end = Column(Time, nullable=False)
    break_minutes = Column(Integer, default=0)
    
    # Дні роботи
    days_of_week = Column(ARRAY(Integer))  # [1,2,3,4,5]
    
    # Надбавка
    rate_multiplier = Column(Numeric(5, 2), default=1.0)
    
    # Статус
    is_active = Column(Boolean, default=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    position_schedules = relationship("PositionSchedule", back_populates="schedule")
    
    # Constraints
    __table_args__ = (
        CheckConstraint('rate_multiplier > 0', name='schedule_rate_check'),
    )
    
    def __repr__(self):
        return f"<ShiftSchedule(code='{self.code}', name='{self.name}')>"
class PositionGroup(Base):
    __tablename__ = "position_groups"
    
    id = Column(Integer, primary_key=True)
    
    # Зв'язки
    position_id = Column(Integer, ForeignKey("positions.id", ondelete="CASCADE"), nullable=False, index=True)
    group_id = Column(Integer, ForeignKey("groups.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Період дії
    valid_from = Column(DateTime(timezone=True), nullable=False, index=True)
    valid_until = Column(DateTime(timezone=True), index=True)
    
    # Додаткові параметри
    meta_data = Column(JSONB)  # {"children_count": 2, "disability_degree": "2"}
    
    # Документи-підстави
    document_number = Column(String(100))
    document_date = Column(Date)
    
    # Статус
    is_active = Column(Boolean, default=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    created_by = Column(String(100), nullable=False, server_default="system")
    
    # Relationships
    position = relationship("Position", back_populates="position_groups")
    group = relationship("Group", back_populates="position_groups")
    
    # Constraints
    __table_args__ = (
        CheckConstraint('valid_until IS NULL OR valid_until > valid_from', name='pg_dates_check'),
        UniqueConstraint('position_id', 'group_id', 'valid_from', name='uq_position_group_date'),
    )
    
    def __repr__(self):
        return f"<PositionGroup(position_id={self.position_id}, group_id={self.group_id})>"
class Position(Base):
    __tablename__ = "positions"
    
    id = Column(Integer, primary_key=True)
    
    # Зв'язки
    employee_id = Column(Integer, ForeignKey("employees.id", ondelete="CASCADE"), nullable=False, index=True)
    organizational_unit_id = Column(Integer, ForeignKey("organizational_units.id"), nullable=False, index=True)
    
    # Ідентифікація
    position_code = Column(String(50), unique=True, nullable=False, index=True)
    position_name = Column(String(255), nullable=False)
    
    # Умови роботи
    employment_rate = Column(Numeric(5, 4), nullable=False, default=1.0)  # 1.0 = 100%
    
    # Період дії
    start_date = Column(Date, nullable=False)
    end_date = Column(Date)
    
    # Статус
    is_active = Column(Boolean, default=True, index=True)
    
    # Метадані
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    created_by = Column(String(100), nullable=False)
    
    # Relationships
    employee = relationship("Employee", back_populates="positions")
    organizational_unit = relationship("OrganizationalUnit", back_populates="positions")
    position_groups = relationship("PositionGroup", back_populates="position", cascade="all, delete-orphan")
    position_schedules = relationship("PositionSchedule", back_populates="position", cascade="all, delete-orphan")
    contracts = relationship("Contract", back_populates="position", cascade="all, delete-orphan")
    timesheets = relationship("Timesheet", back_populates="position", cascade="all, delete-orphan")
    accrual_results = relationship("AccrualResult", back_populates="position")
    
    # Constraints
    __table_args__ = (
        CheckConstraint('employment_rate > 0 AND employment_rate <= 2.0', name='positions_rate_check'),
        CheckConstraint('end_date IS NULL OR end_date >= start_date', name='positions_dates_check'),
    )
    
    def __repr__(self):
        return f"<Position(id={self.id}, code='{self.position_code}', rate={self.employment_rate})>"

class Group(Base):
    __tablename__ = "groups"
    
    id = Column(Integer, primary_key=True)
    parent_id = Column(Integer, ForeignKey("groups.id", ondelete="SET NULL"), nullable=True)
    
    # Ідентифікація
    code = Column(String(50), unique=True, nullable=False, index=True)
    name = Column(String(255), nullable=False)
    description = Column(Text)
    
    # Ієрархія
    level = Column(Integer, nullable=False, default=1, server_default="1")
    full_path = Column(String(500))
    
    # Тип групи
    group_type = Column(String(50), index=True)  # social, professional, administrative
    
    # Метадані
    is_active = Column(Boolean, default=True, server_default="true", index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    parent = relationship("Group", remote_side=[id], backref="children")
    position_groups = relationship("PositionGroup", back_populates="group", cascade="all, delete-orphan")
    calculation_rules = relationship("CalculationRule", back_populates="group")
    
    # Constraints
    __table_args__ = (
        CheckConstraint('id != parent_id', name='groups_check'),
        CheckConstraint('level > 0', name='groups_level_check'),
    )
    
    def __repr__(self):
        return f"<Group(id={self.id}, code='{self.code}', name='{self.name}', level={self.level})>"
class OrganizationalUnit(Base):
    __tablename__ = "organizational_units"

    id = Column(Integer, primary_key=True)
    parent_id = Column(Integer, ForeignKey("organizational_units.id", ondelete="SET NULL"))

    # Ідентифікація
    code = Column(String(50), unique=True, nullable=False, index=True)
    name = Column(String(255), nullable=False)

    # Ієрархія
    level = Column(Integer, nullable=False, default=1)

    # Метадані
    is_active = Column(Boolean, default=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    parent = relationship("OrganizationalUnit", remote_side=[id], backref="children")
    positions = relationship("Position", back_populates="organizational_unit")

    # Constraints
    __table_args__ = (
        CheckConstraint('id != parent_id', name='org_unit_check'),
        CheckConstraint('level > 0', name='org_unit_level_check'),
    )

    def __repr__(self):
        return f"<OrganizationalUnit(id={self.id}, code='{self.code}', name='{self.name}')>"


class Employee(Base):
    __tablename__ = "employees"

    id = Column(Integer, primary_key=True)

    # Ідентифікація
    personnel_number = Column(String(50), unique=True, nullable=False, index=True)
    tax_number = Column(String(50), index=True)

    # ПІБ
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    middle_name = Column(String(100))

    # Дати
    birth_date = Column(Date)
    hire_date = Column(Date, nullable=False)
    termination_date = Column(Date)

    # Контактна інформація
    email = Column(String(255))
    phone = Column(String(50))
    address = Column(Text)

    # Статус
    status = Column(String(20), default='active')  # active, on_leave, terminated

    # Метадані
    is_active = Column(Boolean, default=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    created_by = Column(String(100), nullable=False)

    # Relationships (v2.0: employees connect to org units through positions)
    positions = relationship("Position", back_populates="employee", cascade="all, delete-orphan")

    # Constraints
    __table_args__ = (
        CheckConstraint('termination_date IS NULL OR termination_date >= hire_date',
                       name='employee_dates_check'),
    )

    def __repr__(self):
        return f"<Employee(id={self.id}, personnel_number='{self.personnel_number}', name='{self.first_name} {self.last_name}')>"




class PositionSchedule(Base):
    __tablename__ = "position_schedules"
    
    id = Column(Integer, primary_key=True)
    
    # Зв'язки
    position_id = Column(Integer, ForeignKey("positions.id", ondelete="CASCADE"), nullable=False, index=True)
    schedule_id = Column(Integer, ForeignKey("shift_schedules.id"), nullable=False, index=True)
    
    # Період дії
    valid_from = Column(DateTime(timezone=True), nullable=False, index=True)
    valid_until = Column(DateTime(timezone=True), index=True)
    
    # Статус
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    position = relationship("Position", back_populates="position_schedules")
    schedule = relationship("ShiftSchedule", back_populates="position_schedules")
    
    # Constraints
    __table_args__ = (
        CheckConstraint('valid_until IS NULL OR valid_until > valid_from', name='ps_dates_check'),
    )
    
    def __repr__(self):
        return f"<PositionSchedule(position_id={self.position_id}, schedule_id={self.schedule_id})>"

class Contract(Base):
    __tablename__ = "contracts"

    id = Column(Integer, primary_key=True)

    # Зв'язок з позицією (v2.0)
    position_id = Column(Integer, ForeignKey("positions.id", ondelete="CASCADE"), nullable=False, index=True)

    # Тип контракту
    contract_type = Column(String(20), nullable=False, index=True)  # salary, hourly, piecework, task_based

    # Умови оплати
    base_rate = Column(Numeric(12, 2), nullable=False)
    currency = Column(String(3), default="UAH")

    # Період дії (TIMESTAMP для точності!)
    start_datetime = Column(DateTime(timezone=True), nullable=False, index=True)
    end_datetime = Column(DateTime(timezone=True), index=True)

    # Статус
    is_active = Column(Boolean, default=True, index=True)

    # Метадані
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    created_by = Column(String(100), nullable=False)
    notes = Column(Text)

    # Relationships
    position = relationship("Position", back_populates="contracts")

    # Constraints
    __table_args__ = (
        CheckConstraint('base_rate >= 0', name='contract_rate_check'),
        CheckConstraint('end_datetime IS NULL OR end_datetime > start_datetime', name='contract_dates_check'),
    )

    def __repr__(self):
        return f"<Contract(id={self.id}, position_id={self.position_id}, type='{self.contract_type}', rate={self.base_rate})>"
class CalculationRule(Base):
    """Правила розрахунку - МІНІМАЛЬНА ВЕРСІЯ"""
    __tablename__ = "calculation_rules"
    
    id = Column(Integer, primary_key=True)
    
    # Scope (тільки ОДНЕ може бути NOT NULL!)
    position_id = Column(Integer, ForeignKey("positions.id", ondelete="CASCADE"), index=True)
    organizational_unit_id = Column(Integer, ForeignKey("organizational_units.id", ondelete="CASCADE"), index=True)
    group_id = Column(Integer, ForeignKey("groups.id", ondelete="SET NULL"), index=True)
    
    # Ідентифікація
    code = Column(String(50), nullable=False, index=True)
    name = Column(String(255), nullable=False)
    
    # Логіка
    sql_code = Column(Text)
    rule_type = Column(String(20), nullable=False, index=True)
    
    # Період дії (TIMESTAMP!)
    valid_from = Column(DateTime(timezone=True), nullable=False, index=True)
    valid_until = Column(DateTime(timezone=True), index=True)
    
    # Статус
    is_active = Column(Boolean, default=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    created_by = Column(String(100), nullable=False)
    
    # Relationships (МІНІМУМ)
    position = relationship("Position")
    organizational_unit = relationship("OrganizationalUnit")
    group = relationship("Group", back_populates="calculation_rules")
    template_rules = relationship("TemplateRule", back_populates="rule")

    def __repr__(self):
        return f"<CalculationRule(id={self.id}, code='{self.code}')>"
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
