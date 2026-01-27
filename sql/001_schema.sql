-- ============================================================================
-- СИСТЕМА ОБЛІКУ ЗАРОБІТНОЇ ПЛАТИ "ZARPLATA"
-- База даних: SQLite
-- Версія: 1.0
-- ============================================================================

-- ============================================================================
-- БЛОК 1: ДОВІДНИКИ (REFERENCES)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1.1. Підрозділи (необмежена ієрархія - дерево)
-- ----------------------------------------------------------------------------
CREATE TABLE departments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    parent_id INTEGER REFERENCES departments(id),
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    full_name TEXT,
    full_path TEXT,
    level INTEGER DEFAULT 0,
    sort_order INTEGER DEFAULT 0,
    manager_employee_id INTEGER,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_departments_parent ON departments(parent_id);
CREATE INDEX idx_departments_active ON departments(is_active);

-- ----------------------------------------------------------------------------
-- 1.2. Посади
-- ----------------------------------------------------------------------------
CREATE TABLE positions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    category TEXT,
    min_salary REAL,
    max_salary REAL,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_positions_active ON positions(is_active);

-- ----------------------------------------------------------------------------
-- 1.3. Категорії працівників (соціальні/пільгові групи)
-- ----------------------------------------------------------------------------
CREATE TABLE employee_categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    category_type TEXT NOT NULL CHECK(category_type IN ('social', 'benefit', 'professional', 'custom')),
    affects_taxes INTEGER DEFAULT 0,
    affects_accruals INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);

-- ----------------------------------------------------------------------------
-- 1.4. Типи нарахувань
-- ----------------------------------------------------------------------------
CREATE TABLE accrual_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    category TEXT NOT NULL CHECK(category IN ('salary', 'bonus', 'allowance', 'compensation', 'vacation', 'sick', 'other')),
    is_taxable INTEGER DEFAULT 1,
    is_included_in_average INTEGER DEFAULT 1,
    calculation_order INTEGER DEFAULT 100,
    is_system INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);

-- ----------------------------------------------------------------------------
-- 1.5. Типи утримань
-- ----------------------------------------------------------------------------
CREATE TABLE deduction_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    category TEXT NOT NULL CHECK(category IN ('tax', 'social', 'executive', 'voluntary', 'other')),
    calculation_base TEXT,
    is_mandatory INTEGER DEFAULT 0,
    calculation_order INTEGER DEFAULT 100,
    is_system INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);

-- ----------------------------------------------------------------------------
-- 1.6. Типи робочого часу
-- ----------------------------------------------------------------------------
CREATE TABLE work_time_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    short_name TEXT NOT NULL,
    category TEXT NOT NULL CHECK(category IN ('work', 'paid_leave', 'unpaid_leave', 'absence')),
    pay_coefficient REAL DEFAULT 1.0,
    counts_as_worked INTEGER DEFAULT 1,
    requires_document INTEGER DEFAULT 0,
    color TEXT DEFAULT '#4CAF50',
    sort_order INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1
);

-- ----------------------------------------------------------------------------
-- 1.7. Модулі розрахунку
-- ----------------------------------------------------------------------------
CREATE TABLE calculation_modules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    primary_table TEXT NOT NULL,
    formula_template TEXT,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);

-- ----------------------------------------------------------------------------
-- 1.8. Шаблони графіків роботи
-- ----------------------------------------------------------------------------
CREATE TABLE work_time_templates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    template_type TEXT NOT NULL CHECK(template_type IN ('standard', 'shift', 'flexible', 'individual')),
    is_default INTEGER DEFAULT 0,
    settings TEXT,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);

-- ----------------------------------------------------------------------------
-- 1.9. Дні шаблону графіка
-- ----------------------------------------------------------------------------
CREATE TABLE work_time_template_days (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    template_id INTEGER NOT NULL REFERENCES work_time_templates(id),
    day_of_week INTEGER NOT NULL CHECK(day_of_week BETWEEN 1 AND 7),
    is_work_day INTEGER DEFAULT 1,
    hours REAL DEFAULT 8,
    start_time TEXT DEFAULT '09:00',
    end_time TEXT DEFAULT '18:00',
    break_minutes INTEGER DEFAULT 60,
    work_time_type_id INTEGER REFERENCES work_time_types(id)
);

CREATE INDEX idx_template_days_template ON work_time_template_days(template_id);

-- ============================================================================
-- БЛОК 2: КОРИСТУВАЧІ ТА БЕЗПЕКА
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 2.1. Користувачі
-- ----------------------------------------------------------------------------
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    email TEXT,
    employee_id INTEGER,
    is_admin INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1,
    last_login TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

-- ----------------------------------------------------------------------------
-- 2.2. Ролі
-- ----------------------------------------------------------------------------
CREATE TABLE roles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    is_system INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);

-- ----------------------------------------------------------------------------
-- 2.3. Дозволи (permissions)
-- ----------------------------------------------------------------------------
CREATE TABLE permissions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    category TEXT,
    description TEXT,
    is_active INTEGER DEFAULT 1
);

-- ----------------------------------------------------------------------------
-- 2.4. Дозволи ролей
-- ----------------------------------------------------------------------------
CREATE TABLE role_permissions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    role_id INTEGER NOT NULL REFERENCES roles(id),
    permission_id INTEGER NOT NULL REFERENCES permissions(id),
    scope_type TEXT CHECK(scope_type IN ('enterprise', 'department', 'position', 'employee')),
    scope_id INTEGER,
    conditions TEXT,
    UNIQUE(role_id, permission_id, scope_type, scope_id)
);

CREATE INDEX idx_role_permissions_role ON role_permissions(role_id);

-- ============================================================================
-- БЛОК 3: ПРАЦІВНИКИ
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 3.1. Працівники
-- ----------------------------------------------------------------------------
CREATE TABLE employees (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    personnel_number TEXT UNIQUE NOT NULL,
    last_name TEXT NOT NULL,
    first_name TEXT NOT NULL,
    middle_name TEXT,
    birth_date TEXT,
    gender TEXT CHECK(gender IN ('M', 'F')),
    tax_id TEXT,
    passport_series TEXT,
    passport_number TEXT,
    passport_issued_by TEXT,
    passport_issued_date TEXT,
    address TEXT,
    phone TEXT,
    email TEXT,
    photo_path TEXT,
    hire_date TEXT,
    fire_date TEXT,
    fire_reason TEXT,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_employees_active ON employees(is_active);
CREATE INDEX idx_employees_name ON employees(last_name, first_name);
CREATE INDEX idx_employees_personnel ON employees(personnel_number);

-- ----------------------------------------------------------------------------
-- 3.2. Призначення (assignment) - множинні, з історією
-- ----------------------------------------------------------------------------
CREATE TABLE employee_assignments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    department_id INTEGER REFERENCES departments(id),
    position_id INTEGER REFERENCES positions(id),
    assignment_type TEXT NOT NULL CHECK(assignment_type IN ('primary', 'secondary', 'temporary', 'civil')),
    calculation_module_id INTEGER REFERENCES calculation_modules(id),
    rate REAL DEFAULT 1.0,
    base_salary REAL,
    hourly_rate REAL,
    start_date TEXT NOT NULL,
    end_date TEXT,
    order_number TEXT,
    order_date TEXT,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_assignments_employee ON employee_assignments(employee_id);
CREATE INDEX idx_assignments_department ON employee_assignments(department_id);
CREATE INDEX idx_assignments_position ON employee_assignments(position_id);
CREATE INDEX idx_assignments_active ON employee_assignments(is_active);
CREATE INDEX idx_assignments_dates ON employee_assignments(start_date, end_date);

-- ----------------------------------------------------------------------------
-- 3.3. Належність до категорій
-- ----------------------------------------------------------------------------
CREATE TABLE employee_category_membership (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    category_id INTEGER NOT NULL REFERENCES employee_categories(id),
    start_date TEXT NOT NULL,
    end_date TEXT,
    document_number TEXT,
    document_date TEXT,
    notes TEXT,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_category_membership_employee ON employee_category_membership(employee_id);
CREATE INDEX idx_category_membership_category ON employee_category_membership(category_id);

-- ----------------------------------------------------------------------------
-- 3.4. Графіки роботи працівників
-- ----------------------------------------------------------------------------
CREATE TABLE employee_work_schedules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    assignment_id INTEGER REFERENCES employee_assignments(id),
    template_id INTEGER NOT NULL REFERENCES work_time_templates(id),
    start_date TEXT NOT NULL,
    end_date TEXT,
    custom_settings TEXT,
    reason TEXT,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_work_schedules_employee ON employee_work_schedules(employee_id);

-- ----------------------------------------------------------------------------
-- 3.5. Умови договорів
-- ----------------------------------------------------------------------------
CREATE TABLE employee_contract_terms (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    assignment_id INTEGER REFERENCES employee_assignments(id),
    contract_number TEXT,
    contract_date TEXT,
    valid_from TEXT NOT NULL,
    valid_until TEXT,
    contract_type TEXT NOT NULL CHECK(contract_type IN ('standard', 'individual', 'temporary', 'civil', 'remote')),
    base_conditions TEXT,
    document_path TEXT,
    status TEXT DEFAULT 'active' CHECK(status IN ('draft', 'active', 'expired', 'terminated')),
    created_by INTEGER REFERENCES users(id),
    approved_by INTEGER REFERENCES users(id),
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_contract_terms_employee ON employee_contract_terms(employee_id);

-- ----------------------------------------------------------------------------
-- 3.6. Правила нарахувань в договорі (перевизначення)
-- ----------------------------------------------------------------------------
CREATE TABLE employee_contract_accrual_rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    contract_id INTEGER NOT NULL REFERENCES employee_contract_terms(id),
    rule_template_id INTEGER NOT NULL REFERENCES accrual_rule_templates(id),
    override_params TEXT NOT NULL,
    override_conditions TEXT,
    reason TEXT,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_contract_rules_contract ON employee_contract_accrual_rules(contract_id);

-- ============================================================================
-- БЛОК 4: ПРАВИЛА НАРАХУВАНЬ
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 4.1. Шаблони правил нарахувань
-- ----------------------------------------------------------------------------
CREATE TABLE accrual_rule_templates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    accrual_type_id INTEGER REFERENCES accrual_types(id),
    category TEXT NOT NULL CHECK(category IN ('time_based', 'position_based', 'performance_based', 'social_based', 'contractual')),
    formula TEXT NOT NULL,
    default_params TEXT NOT NULL,
    conditions TEXT,
    priority INTEGER DEFAULT 10,
    level TEXT NOT NULL CHECK(level IN ('system', 'company', 'department', 'position', 'category', 'individual')),
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_rule_templates_level ON accrual_rule_templates(level);

-- ----------------------------------------------------------------------------
-- 4.2. Призначення правил (по scope)
-- ----------------------------------------------------------------------------
CREATE TABLE accrual_assignments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    rule_template_id INTEGER NOT NULL REFERENCES accrual_rule_templates(id),
    scope_type TEXT NOT NULL CHECK(scope_type IN ('enterprise', 'department', 'position', 'category', 'group', 'employee')),
    scope_id INTEGER,
    params_override TEXT,
    valid_from TEXT NOT NULL,
    valid_until TEXT,
    priority INTEGER DEFAULT 10,
    is_active INTEGER DEFAULT 1,
    created_by INTEGER REFERENCES users(id),
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_accrual_assignments_scope ON accrual_assignments(scope_type, scope_id);
CREATE INDEX idx_accrual_assignments_rule ON accrual_assignments(rule_template_id);

-- ----------------------------------------------------------------------------
-- 4.3. Застосовані правила працівника (кеш)
-- ----------------------------------------------------------------------------
CREATE TABLE employee_applied_rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    assignment_id INTEGER REFERENCES employee_assignments(id),
    rule_template_id INTEGER NOT NULL REFERENCES accrual_rule_templates(id),
    source_type TEXT NOT NULL,
    source_id INTEGER,
    effective_params TEXT NOT NULL,
    priority INTEGER NOT NULL,
    valid_from TEXT NOT NULL,
    valid_until TEXT,
    reason TEXT,
    approved_by INTEGER REFERENCES users(id),
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_applied_rules_employee ON employee_applied_rules(employee_id);

-- ============================================================================
-- БЛОК 5: ПЕРІОДИ ТА ПІДПЕРІОДИ
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 5.1. Розрахункові періоди (з scope)
-- ----------------------------------------------------------------------------
CREATE TABLE payroll_periods (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    period_type TEXT NOT NULL CHECK(period_type IN ('month', 'decade', 'week', 'custom')),
    name TEXT NOT NULL,
    start_date TEXT NOT NULL,
    end_date TEXT NOT NULL,
    work_days INTEGER,
    work_hours REAL,
    scope_type TEXT DEFAULT 'enterprise' CHECK(scope_type IN ('enterprise', 'department', 'position', 'category', 'group', 'employee')),
    scope_id INTEGER,
    status TEXT DEFAULT 'open' CHECK(status IN ('open', 'calculating', 'calculated', 'closed', 'archived')),
    closed_at TEXT,
    closed_by INTEGER REFERENCES users(id),
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_periods_dates ON payroll_periods(start_date, end_date);
CREATE INDEX idx_periods_status ON payroll_periods(status);
CREATE INDEX idx_periods_scope ON payroll_periods(scope_type, scope_id);

-- ----------------------------------------------------------------------------
-- 5.2. Підперіоди (для обліку змін всередині періоду)
-- ----------------------------------------------------------------------------
CREATE TABLE payroll_subperiods (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    period_id INTEGER NOT NULL REFERENCES payroll_periods(id),
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    assignment_id INTEGER REFERENCES employee_assignments(id),
    subperiod_number INTEGER NOT NULL,
    start_date TEXT NOT NULL,
    end_date TEXT NOT NULL,
    work_days INTEGER,
    work_hours REAL,
    change_type TEXT CHECK(change_type IN ('rate_change', 'transfer', 'module_change', 'rule_change', 'tax_change', 'status_change', 'contract_change')),
    change_document_id INTEGER,
    change_description TEXT,
    params_snapshot TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_subperiods_period ON payroll_subperiods(period_id);
CREATE INDEX idx_subperiods_employee ON payroll_subperiods(employee_id);

-- ============================================================================
-- БЛОК 6: ДОКУМЕНТИ (ПРОМІЖНІ ТАБЛИЦІ DOC_*)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 6.1. Налаштування workflow
-- ----------------------------------------------------------------------------
CREATE TABLE workflow_settings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_type TEXT NOT NULL,
    workflow_mode TEXT NOT NULL CHECK(workflow_mode IN ('simple', 'fast', 'strict')),
    stages TEXT NOT NULL,
    conditions TEXT,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);

-- ----------------------------------------------------------------------------
-- 6.2. Етапи workflow
-- ----------------------------------------------------------------------------
CREATE TABLE workflow_stages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    document_type TEXT NOT NULL,
    stage_order INTEGER NOT NULL,
    required_role_id INTEGER REFERENCES roles(id),
    required_permission TEXT,
    can_skip INTEGER DEFAULT 0,
    auto_approve_conditions TEXT,
    is_active INTEGER DEFAULT 1
);

-- ----------------------------------------------------------------------------
-- 6.3. Табелі робочого часу
-- ----------------------------------------------------------------------------
CREATE TABLE doc_timesheets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_number TEXT UNIQUE NOT NULL,
    document_date TEXT NOT NULL,
    period_id INTEGER NOT NULL REFERENCES payroll_periods(id),
    scope_type TEXT DEFAULT 'enterprise' CHECK(scope_type IN ('enterprise', 'department', 'position', 'category', 'group', 'employee')),
    scope_id INTEGER,
    creation_method TEXT DEFAULT 'manual' CHECK(creation_method IN ('manual', 'template', 'import', 'mixed')),
    template_applied INTEGER DEFAULT 0,
    exceptions_count INTEGER DEFAULT 0,
    status TEXT DEFAULT 'draft' CHECK(status IN ('draft', 'pending_review', 'pending_approval', 'pending_signature', 'approved', 'posted', 'rejected')),
    responsible_id INTEGER REFERENCES users(id),
    posted_at TEXT,
    posted_by INTEGER REFERENCES users(id),
    notes TEXT,
    created_by INTEGER REFERENCES users(id),
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_timesheets_period ON doc_timesheets(period_id);
CREATE INDEX idx_timesheets_status ON doc_timesheets(status);

-- ----------------------------------------------------------------------------
-- 6.4. Рядки табелю
-- ----------------------------------------------------------------------------
CREATE TABLE doc_timesheet_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id INTEGER NOT NULL REFERENCES doc_timesheets(id),
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    assignment_id INTEGER REFERENCES employee_assignments(id),
    work_date TEXT NOT NULL,
    work_time_type_id INTEGER NOT NULL REFERENCES work_time_types(id),
    hours REAL NOT NULL,
    start_time TEXT,
    end_time TEXT,
    source TEXT DEFAULT 'template' CHECK(source IN ('template', 'manual', 'import', 'correction')),
    notes TEXT,
    confirmed INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_timesheet_records_doc ON doc_timesheet_records(document_id);
CREATE INDEX idx_timesheet_records_employee ON doc_timesheet_records(employee_id);
CREATE INDEX idx_timesheet_records_date ON doc_timesheet_records(work_date);

-- ----------------------------------------------------------------------------
-- 6.5. Відрядна робота (для модуля piecework)
-- ----------------------------------------------------------------------------
CREATE TABLE doc_piecework_production (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_number TEXT UNIQUE NOT NULL,
    document_date TEXT NOT NULL,
    period_id INTEGER NOT NULL REFERENCES payroll_periods(id),
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    assignment_id INTEGER REFERENCES employee_assignments(id),
    product_code TEXT NOT NULL,
    product_name TEXT NOT NULL,
    quantity REAL NOT NULL,
    rate_per_unit REAL NOT NULL,
    amount REAL NOT NULL,
    bonus_percent REAL DEFAULT 0,
    bonus_amount REAL DEFAULT 0,
    total_amount REAL NOT NULL,
    status TEXT DEFAULT 'draft',
    posted_at TEXT,
    notes TEXT,
    created_by INTEGER REFERENCES users(id),
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_piecework_period ON doc_piecework_production(period_id);
CREATE INDEX idx_piecework_employee ON doc_piecework_production(employee_id);

-- ----------------------------------------------------------------------------
-- 6.6. Акордна робота (для модуля task)
-- ----------------------------------------------------------------------------
CREATE TABLE doc_task_completion (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_number TEXT UNIQUE NOT NULL,
    document_date TEXT NOT NULL,
    period_id INTEGER NOT NULL REFERENCES payroll_periods(id),
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    assignment_id INTEGER REFERENCES employee_assignments(id),
    task_code TEXT NOT NULL,
    task_name TEXT NOT NULL,
    task_description TEXT,
    planned_amount REAL NOT NULL,
    completion_percent REAL DEFAULT 100,
    actual_amount REAL NOT NULL,
    completion_date TEXT,
    status TEXT DEFAULT 'draft',
    posted_at TEXT,
    notes TEXT,
    created_by INTEGER REFERENCES users(id),
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_task_period ON doc_task_completion(period_id);
CREATE INDEX idx_task_employee ON doc_task_completion(employee_id);

-- ----------------------------------------------------------------------------
-- 6.7. Нарахування зарплати (головний документ)
-- ----------------------------------------------------------------------------
CREATE TABLE doc_payroll_calculations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_number TEXT UNIQUE NOT NULL,
    document_date TEXT NOT NULL,
    period_id INTEGER NOT NULL REFERENCES payroll_periods(id),
    scope_type TEXT DEFAULT 'enterprise' CHECK(scope_type IN ('enterprise', 'department', 'position', 'category', 'group', 'employee')),
    scope_id INTEGER,
    scope_filter TEXT,
    calculation_type TEXT DEFAULT 'full' CHECK(calculation_type IN ('full', 'advance', 'correction', 'final')),
    employees_count INTEGER DEFAULT 0,
    total_accrued REAL DEFAULT 0,
    total_deductions REAL DEFAULT 0,
    total_to_pay REAL DEFAULT 0,
    status TEXT DEFAULT 'draft' CHECK(status IN ('draft', 'pending_review', 'pending_approval', 'pending_signature', 'approved', 'posted', 'rejected')),
    posted_at TEXT,
    posted_by INTEGER REFERENCES users(id),
    notes TEXT,
    created_by INTEGER REFERENCES users(id),
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_payroll_calc_period ON doc_payroll_calculations(period_id);
CREATE INDEX idx_payroll_calc_status ON doc_payroll_calculations(status);
CREATE INDEX idx_payroll_calc_scope ON doc_payroll_calculations(scope_type, scope_id);

-- ----------------------------------------------------------------------------
-- 6.8. Рядки нарахувань (по кожному працівнику/типу)
-- ----------------------------------------------------------------------------
CREATE TABLE doc_payroll_accruals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id INTEGER NOT NULL REFERENCES doc_payroll_calculations(id),
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    assignment_id INTEGER REFERENCES employee_assignments(id),
    subperiod_id INTEGER REFERENCES payroll_subperiods(id),
    accrual_type_id INTEGER NOT NULL REFERENCES accrual_types(id),
    rule_id INTEGER REFERENCES accrual_rule_templates(id),
    base_amount REAL,
    hours REAL,
    days INTEGER,
    rate REAL,
    coefficient REAL DEFAULT 1.0,
    amount REAL NOT NULL,
    calculation_details TEXT,
    is_manual INTEGER DEFAULT 0,
    notes TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_payroll_accruals_doc ON doc_payroll_accruals(document_id);
CREATE INDEX idx_payroll_accruals_employee ON doc_payroll_accruals(employee_id);

-- ----------------------------------------------------------------------------
-- 6.9. Рядки утримань
-- ----------------------------------------------------------------------------
CREATE TABLE doc_payroll_deductions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id INTEGER NOT NULL REFERENCES doc_payroll_calculations(id),
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    assignment_id INTEGER REFERENCES employee_assignments(id),
    deduction_type_id INTEGER NOT NULL REFERENCES deduction_types(id),
    base_amount REAL,
    rate REAL,
    amount REAL NOT NULL,
    calculation_details TEXT,
    is_manual INTEGER DEFAULT 0,
    notes TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_payroll_deductions_doc ON doc_payroll_deductions(document_id);
CREATE INDEX idx_payroll_deductions_employee ON doc_payroll_deductions(employee_id);

-- ----------------------------------------------------------------------------
-- 6.10. Виплати
-- ----------------------------------------------------------------------------
CREATE TABLE doc_payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_number TEXT UNIQUE NOT NULL,
    document_date TEXT NOT NULL,
    period_id INTEGER NOT NULL REFERENCES payroll_periods(id),
    scope_type TEXT DEFAULT 'enterprise' CHECK(scope_type IN ('enterprise', 'department', 'position', 'category', 'group', 'employee')),
    scope_id INTEGER,
    scope_filter TEXT,
    payment_type TEXT NOT NULL CHECK(payment_type IN ('salary', 'advance', 'vacation', 'sick', 'bonus', 'other')),
    payment_method TEXT DEFAULT 'bank' CHECK(payment_method IN ('cash', 'bank', 'card')),
    bank_account TEXT,
    employees_count INTEGER DEFAULT 0,
    total_amount REAL DEFAULT 0,
    status TEXT DEFAULT 'draft' CHECK(status IN ('draft', 'pending_approval', 'approved', 'paid', 'cancelled')),
    approved_at TEXT,
    approved_by INTEGER REFERENCES users(id),
    paid_at TEXT,
    paid_by INTEGER REFERENCES users(id),
    notes TEXT,
    created_by INTEGER REFERENCES users(id),
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_payments_period ON doc_payments(period_id);
CREATE INDEX idx_payments_status ON doc_payments(status);

-- ----------------------------------------------------------------------------
-- 6.11. Рядки виплат
-- ----------------------------------------------------------------------------
CREATE TABLE doc_payment_lines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id INTEGER NOT NULL REFERENCES doc_payments(id),
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    assignment_id INTEGER REFERENCES employee_assignments(id),
    amount REAL NOT NULL,
    payment_method TEXT DEFAULT 'bank',
    bank_account TEXT,
    is_paid INTEGER DEFAULT 0,
    paid_at TEXT,
    notes TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_payment_lines_doc ON doc_payment_lines(document_id);
CREATE INDEX idx_payment_lines_employee ON doc_payment_lines(employee_id);

-- ----------------------------------------------------------------------------
-- 6.12. Зміни договору
-- ----------------------------------------------------------------------------
CREATE TABLE doc_contract_amendments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_number TEXT UNIQUE NOT NULL,
    document_date TEXT NOT NULL,
    contract_id INTEGER NOT NULL REFERENCES employee_contract_terms(id),
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    change_type TEXT NOT NULL CHECK(change_type IN ('salary_change', 'rules_change', 'schedule_change', 'position_change', 'conditions_change')),
    effective_date TEXT NOT NULL,
    old_values TEXT,
    new_values TEXT,
    reason TEXT,
    status TEXT DEFAULT 'draft' CHECK(status IN ('draft', 'pending_approval', 'approved', 'posted', 'rejected')),
    posted_at TEXT,
    posted_by INTEGER REFERENCES users(id),
    document_path TEXT,
    created_by INTEGER REFERENCES users(id),
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_contract_amendments_contract ON doc_contract_amendments(contract_id);
CREATE INDEX idx_contract_amendments_employee ON doc_contract_amendments(employee_id);

-- ----------------------------------------------------------------------------
-- 6.13. Надання прав доступу
-- ----------------------------------------------------------------------------
CREATE TABLE doc_access_grants (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_number TEXT UNIQUE NOT NULL,
    document_date TEXT NOT NULL,
    user_id INTEGER NOT NULL REFERENCES users(id),
    grant_type TEXT NOT NULL CHECK(grant_type IN ('role', 'permission', 'both')),
    role_id INTEGER REFERENCES roles(id),
    permissions TEXT,
    scope_type TEXT,
    scope_id INTEGER,
    valid_from TEXT NOT NULL,
    valid_until TEXT,
    reason TEXT,
    status TEXT DEFAULT 'draft' CHECK(status IN ('draft', 'pending_approval', 'approved', 'posted', 'rejected', 'revoked')),
    posted_at TEXT,
    posted_by INTEGER REFERENCES users(id),
    revoked_at TEXT,
    revoked_by INTEGER REFERENCES users(id),
    created_by INTEGER REFERENCES users(id),
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_access_grants_user ON doc_access_grants(user_id);
CREATE INDEX idx_access_grants_status ON doc_access_grants(status);

-- ============================================================================
-- БЛОК 7: РЕГІСТРИ (ОСНОВНІ ТАБЛИЦІ REG_*)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 7.1. Регістр робочого часу
-- ----------------------------------------------------------------------------
CREATE TABLE reg_work_time (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id INTEGER NOT NULL,
    document_type TEXT NOT NULL,
    document_date TEXT NOT NULL,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    assignment_id INTEGER REFERENCES employee_assignments(id),
    work_date TEXT NOT NULL,
    work_time_type_id INTEGER NOT NULL REFERENCES work_time_types(id),
    hours REAL NOT NULL,
    source TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_reg_work_time_employee ON reg_work_time(employee_id);
CREATE INDEX idx_reg_work_time_date ON reg_work_time(work_date);
CREATE INDEX idx_reg_work_time_document ON reg_work_time(document_id, document_type);

-- ----------------------------------------------------------------------------
-- 7.2. Регістр нарахувань
-- ----------------------------------------------------------------------------
CREATE TABLE reg_accruals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id INTEGER NOT NULL,
    document_type TEXT NOT NULL,
    document_date TEXT NOT NULL,
    period_id INTEGER NOT NULL REFERENCES payroll_periods(id),
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    assignment_id INTEGER REFERENCES employee_assignments(id),
    subperiod_id INTEGER REFERENCES payroll_subperiods(id),
    accrual_type_id INTEGER NOT NULL REFERENCES accrual_types(id),
    amount REAL NOT NULL,
    calculation_details TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_reg_accruals_employee ON reg_accruals(employee_id);
CREATE INDEX idx_reg_accruals_period ON reg_accruals(period_id);
CREATE INDEX idx_reg_accruals_document ON reg_accruals(document_id, document_type);

-- ----------------------------------------------------------------------------
-- 7.3. Регістр утримань
-- ----------------------------------------------------------------------------
CREATE TABLE reg_deductions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id INTEGER NOT NULL,
    document_type TEXT NOT NULL,
    document_date TEXT NOT NULL,
    period_id INTEGER NOT NULL REFERENCES payroll_periods(id),
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    assignment_id INTEGER REFERENCES employee_assignments(id),
    deduction_type_id INTEGER NOT NULL REFERENCES deduction_types(id),
    amount REAL NOT NULL,
    calculation_details TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_reg_deductions_employee ON reg_deductions(employee_id);
CREATE INDEX idx_reg_deductions_period ON reg_deductions(period_id);

-- ----------------------------------------------------------------------------
-- 7.4. Регістр виплат
-- ----------------------------------------------------------------------------
CREATE TABLE reg_payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id INTEGER NOT NULL REFERENCES doc_payments(id),
    document_date TEXT NOT NULL,
    period_id INTEGER NOT NULL REFERENCES payroll_periods(id),
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    assignment_id INTEGER REFERENCES employee_assignments(id),
    payment_type TEXT NOT NULL,
    amount REAL NOT NULL,
    payment_method TEXT,
    paid_at TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_reg_payments_employee ON reg_payments(employee_id);
CREATE INDEX idx_reg_payments_period ON reg_payments(period_id);

-- ----------------------------------------------------------------------------
-- 7.5. Регістр ролей користувачів
-- ----------------------------------------------------------------------------
CREATE TABLE reg_user_roles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id INTEGER NOT NULL REFERENCES doc_access_grants(id),
    document_date TEXT NOT NULL,
    user_id INTEGER NOT NULL REFERENCES users(id),
    role_id INTEGER NOT NULL REFERENCES roles(id),
    scope_type TEXT,
    scope_id INTEGER,
    valid_from TEXT NOT NULL,
    valid_until TEXT,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_reg_user_roles_user ON reg_user_roles(user_id);
CREATE INDEX idx_reg_user_roles_active ON reg_user_roles(is_active);

-- ----------------------------------------------------------------------------
-- 7.6. Регістр дозволів користувачів
-- ----------------------------------------------------------------------------
CREATE TABLE reg_user_permissions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id INTEGER NOT NULL REFERENCES doc_access_grants(id),
    document_date TEXT NOT NULL,
    user_id INTEGER NOT NULL REFERENCES users(id),
    permission_id INTEGER NOT NULL REFERENCES permissions(id),
    scope_type TEXT,
    scope_id INTEGER,
    conditions TEXT,
    valid_from TEXT NOT NULL,
    valid_until TEXT,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_reg_user_permissions_user ON reg_user_permissions(user_id);

-- ----------------------------------------------------------------------------
-- 7.7. Регістр історії змін
-- ----------------------------------------------------------------------------
CREATE TABLE reg_change_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_type TEXT NOT NULL,
    entity_id INTEGER NOT NULL,
    change_type TEXT NOT NULL CHECK(change_type IN ('create', 'update', 'delete', 'post', 'unpost')),
    old_values TEXT,
    new_values TEXT,
    document_id INTEGER,
    document_type TEXT,
    changed_by INTEGER REFERENCES users(id),
    changed_at TEXT DEFAULT (datetime('now')),
    ip_address TEXT,
    user_agent TEXT
);

CREATE INDEX idx_change_history_entity ON reg_change_history(entity_type, entity_id);
CREATE INDEX idx_change_history_date ON reg_change_history(changed_at);

-- ============================================================================
-- БЛОК 8: СТРУКТУРА РОЗРАХУНКУ (ПРОЗОРІСТЬ)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 8.1. Структура розрахунку (крок за кроком)
-- ----------------------------------------------------------------------------
CREATE TABLE accrual_calculation_structure (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    accrual_id INTEGER NOT NULL,
    accrual_source TEXT NOT NULL,
    step_number INTEGER NOT NULL,
    step_type TEXT NOT NULL CHECK(step_type IN ('input', 'rule', 'calculation', 'adjustment', 'result')),
    step_name TEXT NOT NULL,
    description TEXT,
    input_values TEXT,
    formula TEXT,
    output_value REAL,
    notes TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_calc_structure_accrual ON accrual_calculation_structure(accrual_id, accrual_source);

-- ----------------------------------------------------------------------------
-- 8.2. Застосовані зміни (які зміни вплинули на розрахунок)
-- ----------------------------------------------------------------------------
CREATE TABLE accrual_applied_changes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    accrual_id INTEGER NOT NULL,
    accrual_source TEXT NOT NULL,
    change_type TEXT NOT NULL,
    change_date TEXT NOT NULL,
    document_id INTEGER,
    document_type TEXT,
    old_value TEXT,
    new_value TEXT,
    impact_description TEXT,
    amount_impact REAL,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_applied_changes_accrual ON accrual_applied_changes(accrual_id, accrual_source);

-- ============================================================================
-- БЛОК 9: WORKFLOW ТА ПОГОДЖЕННЯ
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 9.1. Історія погоджень документів
-- ----------------------------------------------------------------------------
CREATE TABLE document_approvals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id INTEGER NOT NULL,
    document_type TEXT NOT NULL,
    stage_id INTEGER NOT NULL REFERENCES workflow_stages(id),
    action TEXT NOT NULL CHECK(action IN ('submit', 'approve', 'reject', 'return', 'skip')),
    user_id INTEGER NOT NULL REFERENCES users(id),
    comments TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_doc_approvals_document ON document_approvals(document_id, document_type);

-- ----------------------------------------------------------------------------
-- 9.2. Історія статусів документів
-- ----------------------------------------------------------------------------
CREATE TABLE document_status_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id INTEGER NOT NULL,
    document_type TEXT NOT NULL,
    old_status TEXT,
    new_status TEXT NOT NULL,
    changed_by INTEGER REFERENCES users(id),
    reason TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_status_history_document ON document_status_history(document_id, document_type);

-- ----------------------------------------------------------------------------
-- 9.3. Сповіщення
-- ----------------------------------------------------------------------------
CREATE TABLE notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id),
    notification_type TEXT NOT NULL,
    title TEXT NOT NULL,
    message TEXT,
    document_id INTEGER,
    document_type TEXT,
    is_read INTEGER DEFAULT 0,
    read_at TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read);

-- ============================================================================
-- БЛОК 10: КОМАНДНИЙ ІНТЕРФЕЙС
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 10.1. Доступні модулі підприємства
-- ----------------------------------------------------------------------------
CREATE TABLE company_modules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    module_code TEXT UNIQUE NOT NULL,
    module_name TEXT NOT NULL,
    description TEXT,
    settings TEXT,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);

-- ----------------------------------------------------------------------------
-- 10.2. Кроки команд (динамічна структура)
-- ----------------------------------------------------------------------------
CREATE TABLE command_steps (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    step_key TEXT UNIQUE NOT NULL,
    parent_step TEXT,
    label TEXT NOT NULL,
    depends_on_module TEXT,
    next_step_type TEXT CHECK(next_step_type IN ('static', 'dynamic', 'query', 'input', 'final')),
    next_step_source TEXT,
    icon TEXT,
    sort_order INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1
);

-- ----------------------------------------------------------------------------
-- 10.3. Опції для кроків команд
-- ----------------------------------------------------------------------------
CREATE TABLE command_step_options (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    step_key TEXT NOT NULL,
    option_id TEXT NOT NULL,
    option_label TEXT NOT NULL,
    next_step TEXT,
    depends_on_module TEXT,
    metadata TEXT,
    icon TEXT,
    sort_order INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1
);

CREATE INDEX idx_step_options_step ON command_step_options(step_key);

-- ----------------------------------------------------------------------------
-- 10.4. Історія виконаних команд
-- ----------------------------------------------------------------------------
CREATE TABLE command_execution_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id),
    session_id TEXT,
    execution_date TEXT DEFAULT (datetime('now')),
    command_path TEXT NOT NULL,
    result_document_id INTEGER,
    result_document_type TEXT,
    execution_time_ms INTEGER,
    is_successful INTEGER DEFAULT 1,
    error_message TEXT
);

CREATE INDEX idx_command_log_user ON command_execution_log(user_id);
CREATE INDEX idx_command_log_date ON command_execution_log(execution_date);

-- ----------------------------------------------------------------------------
-- 10.5. Контекст користувача (для предиктивного вводу)
-- ----------------------------------------------------------------------------
CREATE TABLE user_command_context (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id),
    last_department_id INTEGER,
    last_employee_id INTEGER,
    last_period_id INTEGER,
    recent_commands TEXT,
    frequent_actions TEXT,
    updated_at TEXT DEFAULT (datetime('now')),
    UNIQUE(user_id)
);

-- ----------------------------------------------------------------------------
-- 10.6. Збережені команди користувача
-- ----------------------------------------------------------------------------
CREATE TABLE user_saved_commands (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id),
    command_name TEXT NOT NULL,
    command_template TEXT NOT NULL,
    shortcut_key TEXT,
    is_favorite INTEGER DEFAULT 0,
    usage_count INTEGER DEFAULT 0,
    last_used TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_saved_commands_user ON user_saved_commands(user_id);

-- ============================================================================
-- БЛОК 11: АУДИТ ТА БЕЗПЕКА
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 11.1. Журнал аудиту доступу
-- ----------------------------------------------------------------------------
CREATE TABLE audit_access_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER REFERENCES users(id),
    action TEXT NOT NULL,
    entity_type TEXT,
    entity_id INTEGER,
    details TEXT,
    ip_address TEXT,
    user_agent TEXT,
    session_id TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_audit_log_user ON audit_access_log(user_id);
CREATE INDEX idx_audit_log_date ON audit_access_log(created_at);
CREATE INDEX idx_audit_log_action ON audit_access_log(action);

-- ============================================================================
-- БЛОК 12: ГРУПИ ПРАЦІВНИКІВ
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 12.1. Іменовані групи працівників
-- ----------------------------------------------------------------------------
CREATE TABLE employee_groups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    is_dynamic INTEGER DEFAULT 0,
    dynamic_query TEXT,
    created_by INTEGER REFERENCES users(id),
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);

-- ----------------------------------------------------------------------------
-- 12.2. Члени групи (для статичних груп)
-- ----------------------------------------------------------------------------
CREATE TABLE employee_group_members (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    group_id INTEGER NOT NULL REFERENCES employee_groups(id),
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    added_at TEXT DEFAULT (datetime('now')),
    added_by INTEGER REFERENCES users(id),
    UNIQUE(group_id, employee_id)
);

CREATE INDEX idx_group_members_group ON employee_group_members(group_id);
CREATE INDEX idx_group_members_employee ON employee_group_members(employee_id);

-- ============================================================================
-- БЛОК 13: VIEW (ПРЕДСТАВЛЕННЯ)
-- ============================================================================

-- Активні призначення працівників
CREATE VIEW v_active_assignments AS
SELECT
    ea.id AS assignment_id,
    ea.employee_id,
    e.personnel_number,
    e.last_name,
    e.first_name,
    e.middle_name,
    e.last_name || ' ' || SUBSTR(e.first_name, 1, 1) || '.' ||
        COALESCE(SUBSTR(e.middle_name, 1, 1) || '.', '') AS short_name,
    ea.department_id,
    d.name AS department_name,
    d.full_path AS department_path,
    ea.position_id,
    p.name AS position_name,
    ea.assignment_type,
    ea.calculation_module_id,
    cm.code AS calculation_module_code,
    ea.rate,
    ea.base_salary,
    ea.hourly_rate,
    ea.start_date,
    ea.end_date
FROM employee_assignments ea
JOIN employees e ON e.id = ea.employee_id
LEFT JOIN departments d ON d.id = ea.department_id
LEFT JOIN positions p ON p.id = ea.position_id
LEFT JOIN calculation_modules cm ON cm.id = ea.calculation_module_id
WHERE ea.is_active = 1
  AND e.is_active = 1;

-- Підсумки нарахувань по працівниках
CREATE VIEW v_accrual_summary AS
SELECT
    ra.period_id,
    ra.employee_id,
    e.personnel_number,
    e.last_name || ' ' || e.first_name AS employee_name,
    SUM(ra.amount) AS total_accrued
FROM reg_accruals ra
JOIN employees e ON e.id = ra.employee_id
GROUP BY ra.period_id, ra.employee_id;

-- Підсумки утримань по працівниках
CREATE VIEW v_deduction_summary AS
SELECT
    rd.period_id,
    rd.employee_id,
    e.personnel_number,
    e.last_name || ' ' || e.first_name AS employee_name,
    SUM(rd.amount) AS total_deducted
FROM reg_deductions rd
JOIN employees e ON e.id = rd.employee_id
GROUP BY rd.period_id, rd.employee_id;

-- Підсумок до виплати
CREATE VIEW v_payroll_summary AS
SELECT
    a.period_id,
    a.employee_id,
    a.employee_name,
    a.total_accrued,
    COALESCE(d.total_deducted, 0) AS total_deducted,
    a.total_accrued - COALESCE(d.total_deducted, 0) AS to_pay
FROM v_accrual_summary a
LEFT JOIN v_deduction_summary d
    ON d.period_id = a.period_id
    AND d.employee_id = a.employee_id;

-- Ієрархія підрозділів з кількістю працівників
CREATE VIEW v_departments_tree AS
WITH RECURSIVE dept_tree AS (
    SELECT
        id, parent_id, code, name, full_path, level, sort_order,
        CAST(printf('%05d', sort_order) AS TEXT) AS sort_path
    FROM departments
    WHERE parent_id IS NULL AND is_active = 1

    UNION ALL

    SELECT
        d.id, d.parent_id, d.code, d.name, d.full_path, d.level, d.sort_order,
        dt.sort_path || '/' || CAST(printf('%05d', d.sort_order) AS TEXT)
    FROM departments d
    JOIN dept_tree dt ON d.parent_id = dt.id
    WHERE d.is_active = 1
)
SELECT
    dt.*,
    (SELECT COUNT(DISTINCT ea.employee_id)
     FROM employee_assignments ea
     WHERE ea.department_id = dt.id
       AND ea.is_active = 1) AS direct_employees,
    (SELECT COUNT(DISTINCT ea.employee_id)
     FROM employee_assignments ea
     JOIN departments d2 ON d2.id = ea.department_id
     WHERE (d2.id = dt.id OR d2.full_path LIKE dt.full_path || '/%')
       AND ea.is_active = 1) AS total_employees
FROM dept_tree dt
ORDER BY dt.sort_path;

-- ============================================================================
-- БЛОК 14: ТРИГЕРИ
-- ============================================================================

-- Оновлення full_path для підрозділів
CREATE TRIGGER tr_departments_update_path
AFTER INSERT ON departments
BEGIN
    UPDATE departments
    SET full_path = (
        WITH RECURSIVE path AS (
            SELECT id, parent_id, name, name AS path_name
            FROM departments WHERE id = NEW.id
            UNION ALL
            SELECT d.id, d.parent_id, d.name, d.name || '/' || p.path_name
            FROM departments d
            JOIN path p ON d.id = p.parent_id
        )
        SELECT path_name FROM path WHERE parent_id IS NULL
    ),
    level = (
        WITH RECURSIVE lvl AS (
            SELECT id, parent_id, 0 AS level FROM departments WHERE id = NEW.id
            UNION ALL
            SELECT d.id, d.parent_id, l.level + 1
            FROM departments d JOIN lvl l ON d.id = l.parent_id
        )
        SELECT MAX(level) FROM lvl
    )
    WHERE id = NEW.id;
END;

-- Автоматичне оновлення updated_at
CREATE TRIGGER tr_employees_updated
AFTER UPDATE ON employees
BEGIN
    UPDATE employees SET updated_at = datetime('now') WHERE id = NEW.id;
END;

CREATE TRIGGER tr_assignments_updated
AFTER UPDATE ON employee_assignments
BEGIN
    UPDATE employee_assignments SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- ============================================================================
-- КІНЕЦЬ СХЕМИ
-- ============================================================================
