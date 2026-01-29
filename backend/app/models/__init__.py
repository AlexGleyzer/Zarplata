from app.models.module1 import (
    OrganizationalUnit,
    Employee,
    Contract,
    CalculationRule,
    CalculationTemplate,
    TemplateRule,
    Group,              # НОВЕ!
    Position,           # НОВЕ!
    PositionGroup,      # НОВЕ!
    ShiftSchedule,      # НОВЕ!
    PositionSchedule,   # НОВЕ!
)
from app.models.module2 import (
    WorkResult,
    Timesheet,
    ProductionResult
)
from app.models.module3 import (
    CalculationPeriod,
    AccrualDocument,
    AccrualResult,
    ChangeRequest,
    SplitReason,        # НОВЕ!
)
from app.models.module4 import (
    PaymentRule,
    PaymentDocument,
    PaymentItem,
    BankStatement
)

__all__ = [
    # Module 1
    "OrganizationalUnit",
    "Employee",
    "Contract",
    "CalculationRule",
    "CalculationTemplate",
    "TemplateRule",
    "Group",
    "Position",
    "PositionGroup",
    "ShiftSchedule",
    "PositionSchedule",
    # Module 2
    "WorkResult",
    "Timesheet",
    "ProductionResult",
    # Module 3
    "CalculationPeriod",
    "AccrualDocument",
    "AccrualResult",
    "ChangeRequest",
    "SplitReason",
    # Module 4
    "PaymentRule",
    "PaymentDocument",
    "PaymentItem",
    "BankStatement",
]