-- Модуль 1: Структура Підприємства і Працівники

CREATE TABLE IF NOT EXISTS organizational_units (
    id SERIAL PRIMARY KEY,
    parent_id INTEGER REFERENCES organizational_units(id),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    level INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_org_units_code ON organizational_units(code);
CREATE INDEX idx_org_units_parent ON organizational_units(parent_id);

CREATE TABLE IF NOT EXISTS employees (
    id SERIAL PRIMARY KEY,
    organizational_unit_id INTEGER NOT NULL REFERENCES organizational_units(id),
    personnel_number VARCHAR(20) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100),
    hire_date DATE NOT NULL,
    termination_date DATE,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_employees_personnel ON employees(personnel_number);
CREATE INDEX idx_employees_org_unit ON employees(organizational_unit_id);

CREATE TABLE IF NOT EXISTS contracts (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    organizational_unit_id INTEGER NOT NULL REFERENCES organizational_units(id),
    contract_number VARCHAR(50) UNIQUE NOT NULL,
    contract_type VARCHAR(20) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    base_rate NUMERIC(12, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'UAH' NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS calculation_rules (
    id SERIAL PRIMARY KEY,
    organizational_unit_id INTEGER REFERENCES organizational_units(id),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    sql_code TEXT NOT NULL,
    rule_type VARCHAR(20) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,
    created_by VARCHAR(100) NOT NULL
);

CREATE INDEX idx_calc_rules_code ON calculation_rules(code);

CREATE TABLE IF NOT EXISTS calculation_templates (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_calc_templates_code ON calculation_templates(code);

CREATE TABLE IF NOT EXISTS template_rules (
    id SERIAL PRIMARY KEY,
    template_id INTEGER NOT NULL REFERENCES calculation_templates(id),
    rule_id INTEGER NOT NULL REFERENCES calculation_rules(id),
    execution_order INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL
);

-- Модуль 2: Результати Роботи

CREATE TABLE IF NOT EXISTS work_results (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    organizational_unit_id INTEGER NOT NULL REFERENCES organizational_units(id),
    result_date DATE NOT NULL,
    result_type VARCHAR(20) NOT NULL,
    value NUMERIC(12, 2) NOT NULL,
    unit VARCHAR(20) NOT NULL,
    status VARCHAR(20) DEFAULT 'draft' NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,
    created_by VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS timesheets (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    organizational_unit_id INTEGER NOT NULL REFERENCES organizational_units(id),
    work_date DATE NOT NULL,
    hours_worked INTEGER NOT NULL,
    minutes_worked INTEGER DEFAULT 0 NOT NULL,
    shift_type VARCHAR(20),
    status VARCHAR(20) DEFAULT 'draft' NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS production_results (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    organizational_unit_id INTEGER NOT NULL REFERENCES organizational_units(id),
    work_date DATE NOT NULL,
    product_code VARCHAR(50) NOT NULL,
    quantity NUMERIC(12, 2) NOT NULL,
    quality_coefficient NUMERIC(5, 2) DEFAULT 1.0 NOT NULL,
    status VARCHAR(20) DEFAULT 'draft' NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE
);

-- Модуль 3: Періоди та Нарахування

CREATE TABLE IF NOT EXISTS calculation_periods (
    id SERIAL PRIMARY KEY,
    period_code VARCHAR(50) UNIQUE NOT NULL,
    period_name VARCHAR(255) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    period_type VARCHAR(20) NOT NULL,
    organizational_unit_id INTEGER REFERENCES organizational_units(id),
    employee_id INTEGER REFERENCES employees(id),
    status VARCHAR(20) DEFAULT 'draft' NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,
    created_by VARCHAR(100) NOT NULL
);

CREATE INDEX idx_calc_periods_code ON calculation_periods(period_code);

CREATE TABLE IF NOT EXISTS accrual_documents (
    id SERIAL PRIMARY KEY,
    document_number VARCHAR(50) UNIQUE NOT NULL,
    period_id INTEGER NOT NULL REFERENCES calculation_periods(id),
    template_id INTEGER NOT NULL REFERENCES calculation_templates(id),
    organizational_unit_id INTEGER REFERENCES organizational_units(id),
    employee_id INTEGER REFERENCES employees(id),
    status VARCHAR(20) DEFAULT 'draft' NOT NULL,
    calculation_date TIMESTAMP WITH TIME ZONE,
    approved_date TIMESTAMP WITH TIME ZONE,
    approved_by VARCHAR(100),
    cancelled_date TIMESTAMP WITH TIME ZONE,
    cancelled_by VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,
    created_by VARCHAR(100) NOT NULL
);

CREATE INDEX idx_accrual_docs_number ON accrual_documents(document_number);

CREATE TABLE IF NOT EXISTS accrual_results (
    id SERIAL PRIMARY KEY,
    document_id INTEGER NOT NULL REFERENCES accrual_documents(id),
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    rule_id INTEGER NOT NULL REFERENCES calculation_rules(id),
    rule_code VARCHAR(50) NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    calculation_base NUMERIC(12, 2),
    currency VARCHAR(3) DEFAULT 'UAH' NOT NULL,
    status VARCHAR(20) DEFAULT 'active' NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS change_requests (
    id SERIAL PRIMARY KEY,
    request_number VARCHAR(50) UNIQUE NOT NULL,
    document_id INTEGER NOT NULL REFERENCES accrual_documents(id),
    reason TEXT NOT NULL,
    requested_by VARCHAR(100) NOT NULL,
    request_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'pending' NOT NULL,
    approved_by VARCHAR(100),
    approved_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE
);

-- Модуль 4: Платежі

CREATE TABLE IF NOT EXISTS payment_rules (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    rule_type VARCHAR(30) NOT NULL,
    grouping_logic JSONB,
    recipient_type VARCHAR(30) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS payment_documents (
    id SERIAL PRIMARY KEY,
    document_number VARCHAR(50) UNIQUE NOT NULL,
    period_id INTEGER NOT NULL REFERENCES calculation_periods(id),
    payment_rule_id INTEGER NOT NULL REFERENCES payment_rules(id),
    organizational_unit_id INTEGER REFERENCES organizational_units(id),
    employee_id INTEGER REFERENCES employees(id),
    total_amount NUMERIC(12, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'UAH' NOT NULL,
    payment_date DATE,
    actual_payment_date DATE,
    status VARCHAR(20) DEFAULT 'draft' NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,
    created_by VARCHAR(100) NOT NULL,
    approved_by VARCHAR(100),
    executed_by VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS payment_items (
    id SERIAL PRIMARY KEY,
    payment_document_id INTEGER NOT NULL REFERENCES payment_documents(id),
    accrual_result_id INTEGER NOT NULL REFERENCES accrual_results(id),
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    amount NUMERIC(12, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'UAH' NOT NULL,
    recipient_account VARCHAR(100),
    purpose TEXT,
    status VARCHAR(20) DEFAULT 'pending' NOT NULL
);

CREATE TABLE IF NOT EXISTS bank_statements (
    id SERIAL PRIMARY KEY,
    payment_document_id INTEGER NOT NULL REFERENCES payment_documents(id),
    statement_number VARCHAR(50) NOT NULL,
    file_path VARCHAR(500),
    bank_code VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Seed тестові дані

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
('OPS_HR', 'HR Team', 3, 4, true)
ON CONFLICT (code) DO NOTHING;

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
(10, 'EMP010', 'Zane', 'Brook', '2023-06-10', true)
ON CONFLICT (personnel_number) DO NOTHING;

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
(10, 10, 'CTR-010', 'hourly', '2023-06-10', 150.00, 'UAH', true)
ON CONFLICT (contract_number) DO NOTHING;

INSERT INTO calculation_rules (code, name, description, sql_code, rule_type, is_active, created_by) VALUES
('BASE_SALARY', 'Основна зарплата', 'Нарахування основної заробітної плати згідно контракту',
 'SELECT c.base_rate as amount, e.id as employee_id FROM employees e JOIN contracts c ON c.employee_id = e.id WHERE c.is_active = true AND c.contract_type = ''salary'' AND e.id = :employee_id',
 'accrual', true, 'system'),
('PIT', 'ПДФО 18%', 'Утримання податку на доходи фізичних осіб',
 'SELECT SUM(ar.amount) * 0.18 as amount, ar.employee_id FROM accrual_results ar WHERE ar.document_id = :document_id AND ar.employee_id = :employee_id AND ar.rule_code = ''BASE_SALARY'' AND ar.status = ''active'' GROUP BY ar.employee_id',
 'deduction', true, 'system'),
('WAR_TAX', 'Військовий збір 1.5%', 'Утримання військового збору',
 'SELECT SUM(ar.amount) * 0.015 as amount, ar.employee_id FROM accrual_results ar WHERE ar.document_id = :document_id AND ar.employee_id = :employee_id AND ar.rule_code = ''BASE_SALARY'' AND ar.status = ''active'' GROUP BY ar.employee_id',
 'deduction', true, 'system')
ON CONFLICT (code) DO NOTHING;

INSERT INTO calculation_templates (code, name, description, is_active) VALUES
('MONTHLY_SALARY', 'Місячна зарплата', 'Стандартний шаблон для розрахунку місячної зарплати: нарахування + утримання', true)
ON CONFLICT (code) DO NOTHING;

INSERT INTO template_rules (template_id, rule_id, execution_order, is_active)
SELECT t.id, r.id, 1, true
FROM calculation_templates t, calculation_rules r
WHERE t.code = 'MONTHLY_SALARY' AND r.code = 'BASE_SALARY'
ON CONFLICT DO NOTHING;

INSERT INTO template_rules (template_id, rule_id, execution_order, is_active)
SELECT t.id, r.id, 2, true
FROM calculation_templates t, calculation_rules r
WHERE t.code = 'MONTHLY_SALARY' AND r.code = 'PIT'
ON CONFLICT DO NOTHING;

INSERT INTO template_rules (template_id, rule_id, execution_order, is_active)
SELECT t.id, r.id, 3, true
FROM calculation_templates t, calculation_rules r
WHERE t.code = 'MONTHLY_SALARY' AND r.code = 'WAR_TAX'
ON CONFLICT DO NOTHING;
