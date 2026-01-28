"""Initial seed data

Revision ID: 001_seed_data
Revises: 
Create Date: 2026-01-28

"""
from alembic import op
import sqlalchemy as sa
from datetime import date

# revision identifiers, used by Alembic.
revision = '001_seed_data'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Створення організаційної структури
    op.execute("""
        INSERT INTO organizational_units (code, name, level, parent_id, is_active) VALUES
        ('COMPANY', 'Futura Industries', 1, NULL, true),
        ('SALES', 'Sales Department', 2, 1, true),
        ('ENG', 'Engineering Department', 2, 1, true),
        ('OPS', 'Operations Department', 2, 1, true),
        ('SALES_EAST', 'Sales East', 3, 2, true),
        ('SALES_WEST', 'Sales West', 3, 2, true),
        ('ENG_PLATFORM', 'Platform Team', 3, 3, true),
        ('ENG_PRODUCT', 'Product Team', 3, 3, true),
        ('OPS_FINANCE', 'Finance Team', 3, 4, true),
        ('OPS_HR', 'HR Team', 3, 4, true);
    """)
    
    # Створення працівників
    op.execute("""
        INSERT INTO employees (organizational_unit_id, personnel_number, first_name, last_name, hire_date, is_active) VALUES
        (5, 'EMP001', 'Alex', 'Storm', '2023-01-15', true),
        (5, 'EMP002', 'Mira', 'Vale', '2023-02-01', true),
        (6, 'EMP003', 'Oren', 'Pike', '2023-03-10', true),
        (6, 'EMP004', 'Lina', 'Frost', '2023-03-15', true),
        (7, 'EMP005', 'Dara', 'Bloom', '2023-04-01', true),
        (7, 'EMP006', 'Ilan', 'West', '2023-04-20', true),
        (8, 'EMP007', 'Rhea', 'Stone', '2023-05-01', true),
        (8, 'EMP008', 'Niko', 'Reed', '2023-05-15', true),
        (9, 'EMP009', 'Tara', 'Quinn', '2023-06-01', true),
        (10, 'EMP010', 'Zane', 'Brook', '2023-06-10', true);
    """)
    
    # Створення контрактів
    op.execute("""
        INSERT INTO contracts (employee_id, organizational_unit_id, contract_number, contract_type, start_date, base_rate, currency, is_active) VALUES
        (1, 5, 'CTR-001', 'salary', '2023-01-15', 20000.00, 'UAH', true),
        (2, 5, 'CTR-002', 'salary', '2023-02-01', 20000.00, 'UAH', true),
        (3, 6, 'CTR-003', 'hourly', '2023-03-10', 150.00, 'UAH', true),
        (4, 6, 'CTR-004', 'hourly', '2023-03-15', 150.00, 'UAH', true),
        (5, 7, 'CTR-005', 'salary', '2023-04-01', 18000.00, 'UAH', true),
        (6, 7, 'CTR-006', 'salary', '2023-04-20', 20000.00, 'UAH', true),
        (7, 8, 'CTR-007', 'salary', '2023-05-01', 18000.00, 'UAH', true),
        (8, 8, 'CTR-008', 'salary', '2023-05-15', 20000.00, 'UAH', true),
        (9, 9, 'CTR-009', 'hourly', '2023-06-01', 150.00, 'UAH', true),
        (10, 10, 'CTR-010', 'hourly', '2023-06-10', 150.00, 'UAH', true);
    """)
    
    # Створення правил розрахунків
    op.execute("""
        INSERT INTO calculation_rules (code, name, description, sql_code, rule_type, is_active, created_by) VALUES
        (
            'BASE_SALARY',
            'Основна зарплата',
            'Нарахування основної заробітної плати згідно контракту',
            'SELECT c.base_rate as amount, e.id as employee_id 
             FROM employees e 
             JOIN contracts c ON c.employee_id = e.id 
             WHERE c.is_active = true 
               AND c.contract_type = ''salary''
               AND e.id = :employee_id',
            'accrual',
            true,
            'system'
        ),
        (
            'PIT',
            'ПДФО 18%',
            'Утримання податку на доходи фізичних осіб',
            'SELECT SUM(ar.amount) * 0.18 as amount, ar.employee_id
             FROM accrual_results ar
             WHERE ar.document_id = :document_id
               AND ar.employee_id = :employee_id
               AND ar.rule_code = ''BASE_SALARY''
               AND ar.status = ''active''
             GROUP BY ar.employee_id',
            'deduction',
            true,
            'system'
        ),
        (
            'WAR_TAX',
            'Військовий збір 1.5%',
            'Утримання військового збору',
            'SELECT SUM(ar.amount) * 0.015 as amount, ar.employee_id
             FROM accrual_results ar
             WHERE ar.document_id = :document_id
               AND ar.employee_id = :employee_id
               AND ar.rule_code = ''BASE_SALARY''
               AND ar.status = ''active''
             GROUP BY ar.employee_id',
            'deduction',
            true,
            'system'
        );
    """)
    
    # Створення шаблону
    op.execute("""
        INSERT INTO calculation_templates (code, name, description, is_active) VALUES
        (
            'MONTHLY_SALARY',
            'Місячна зарплата',
            'Стандартний шаблон для розрахунку місячної зарплати: нарахування + утримання',
            true
        );
    """)
    
    # Зв'язок шаблону і правил
    op.execute("""
        INSERT INTO template_rules (template_id, rule_id, execution_order, is_active) VALUES
        (1, 1, 1, true),  -- BASE_SALARY
        (1, 2, 2, true),  -- PIT
        (1, 3, 3, true);  -- WAR_TAX
    """)


def downgrade() -> None:
    # Видалення в зворотньому порядку
    op.execute("DELETE FROM template_rules;")
    op.execute("DELETE FROM calculation_templates;")
    op.execute("DELETE FROM calculation_rules;")
    op.execute("DELETE FROM contracts;")
    op.execute("DELETE FROM employees;")
    op.execute("DELETE FROM organizational_units;")
