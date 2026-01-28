-- 010_seed_mvp_data.sql
-- Seed MVP test data according to payroll_system_architecture.md
-- - Contracts for employees
-- - 2-3 simple rules (base salary, tax)
-- - 1 template with these rules

PRAGMA foreign_keys = ON;

-- ============================================================================
-- CONTRACTS - Create contracts for all employees
-- ============================================================================

INSERT INTO contracts (employee_id, contract_number, contract_type, start_date, base_rate, currency, organizational_unit_id, is_active)
SELECT
  e.id,
  'C-' || e.code,
  CASE
    WHEN e.code IN ('EMP001', 'EMP002', 'EMP006', 'EMP008') THEN 'salary'
    WHEN e.code IN ('EMP003', 'EMP004', 'EMP009', 'EMP010') THEN 'hourly'
    ELSE 'salary'
  END,
  e.hired_at,
  CASE
    WHEN e.code IN ('EMP001', 'EMP002', 'EMP006', 'EMP008') THEN 2000000 -- 20,000 UAH monthly salary
    WHEN e.code IN ('EMP003', 'EMP004', 'EMP009', 'EMP010') THEN 15000 -- 150 UAH hourly rate
    ELSE 1800000 -- 18,000 UAH monthly salary
  END,
  'UAH',
  eoh.org_unit_id,
  1
FROM employees e
JOIN employee_org_unit_history eoh ON e.id = eoh.employee_id
WHERE eoh.valid_to IS NULL;


-- ============================================================================
-- CALCULATION RULES - Simple rules for MVP
-- ============================================================================

-- Rule 1: BASE_SALARY - Base salary calculation
INSERT INTO calculation_rules (
  organizational_unit_id,
  code,
  name,
  description,
  sql_code,
  rule_type,
  is_active,
  created_by
) VALUES (
  NULL, -- Global rule
  'BASE_SALARY',
  'Основна зарплата',
  'Розрахунок основної заробітної плати працівника згідно окладу або погодинної ставки',
  '-- Calculate base salary
SELECT
  employee_id,
  CASE
    WHEN contract_type = ''salary'' THEN base_rate
    WHEN contract_type = ''hourly'' THEN base_rate * hours_worked / 100 -- hours in timesheet
    ELSE 0
  END as amount
FROM contracts c
WHERE c.is_active = 1
  AND :period_start BETWEEN c.start_date AND COALESCE(c.end_date, ''9999-12-31'')',
  'accrual',
  1,
  'system'
);

-- Rule 2: PIT - Personal Income Tax (18%)
INSERT INTO calculation_rules (
  organizational_unit_id,
  code,
  name,
  description,
  sql_code,
  rule_type,
  is_active,
  created_by
) VALUES (
  NULL, -- Global rule
  'PIT',
  'ПДФО (Податок на доходи фізичних осіб)',
  'Розрахунок ПДФО 18% від нарахованої зарплати',
  '-- Calculate PIT (18% of gross salary)
SELECT
  employee_id,
  CAST(SUM(amount) * 0.18 AS INTEGER) as amount
FROM accrual_results ar
WHERE ar.document_id = :document_id
  AND ar.rule_code = ''BASE_SALARY''
  AND ar.status = ''active''
GROUP BY employee_id',
  'deduction',
  1,
  'system'
);

-- Rule 3: WAR_TAX - Military tax (1.5%)
INSERT INTO calculation_rules (
  organizational_unit_id,
  code,
  name,
  description,
  sql_code,
  rule_type,
  is_active,
  created_by
) VALUES (
  NULL, -- Global rule
  'WAR_TAX',
  'Військовий збір',
  'Розрахунок військового збору 1.5% від нарахованої зарплати',
  '-- Calculate War Tax (1.5% of gross salary)
SELECT
  employee_id,
  CAST(SUM(amount) * 0.015 AS INTEGER) as amount
FROM accrual_results ar
WHERE ar.document_id = :document_id
  AND ar.rule_code = ''BASE_SALARY''
  AND ar.status = ''active''
GROUP BY employee_id',
  'deduction',
  1,
  'system'
);


-- ============================================================================
-- CALCULATION TEMPLATE - Monthly salary template
-- ============================================================================

INSERT INTO calculation_templates (code, name, description, is_active)
VALUES (
  'MONTHLY_SALARY',
  'Місячна зарплата',
  'Стандартний шаблон розрахунку місячної заробітної плати з утриманнями ПДФО та військового збору',
  1
);


-- ============================================================================
-- TEMPLATE RULES - Link rules to template in execution order
-- ============================================================================

INSERT INTO template_rules (template_id, rule_id, execution_order, is_active)
SELECT
  (SELECT id FROM calculation_templates WHERE code = 'MONTHLY_SALARY'),
  id,
  CASE code
    WHEN 'BASE_SALARY' THEN 1
    WHEN 'PIT' THEN 2
    WHEN 'WAR_TAX' THEN 3
  END,
  1
FROM calculation_rules
WHERE code IN ('BASE_SALARY', 'PIT', 'WAR_TAX');


-- ============================================================================
-- ACCRUAL TYPES - Types for the rules
-- ============================================================================

-- Ensure accrual types exist for our rules
INSERT OR IGNORE INTO accrual_types (code, name, direction, category, is_active)
VALUES
  ('SALARY', 'Заробітна плата', 'INCOME', 'WAGE', 1),
  ('PIT', 'ПДФО', 'WITHHOLDING', 'TAX', 1),
  ('WAR_TAX', 'Військовий збір', 'WITHHOLDING', 'TAX', 1);


-- ============================================================================
-- BASE VALUES - Minimum wage for reference
-- ============================================================================

INSERT INTO base_values (base_code, value, valid_from, valid_to, comment)
VALUES
  ('MIN_WAGE', 700000, '2024-01-01', NULL, 'Мінімальна зарплата 7000 грн з 01.01.2024'),
  ('LIVING_MINIMUM', 280500, '2024-01-01', NULL, 'Прожитковий мінімум 2805 грн');


-- ============================================================================
-- EMPLOYEE BASES - Set base salaries and hourly rates
-- ============================================================================

INSERT INTO employee_bases (employee_id, base_code, value, valid_from, valid_to)
SELECT
  e.id,
  CASE
    WHEN c.contract_type = 'salary' THEN 'MONTHLY_SALARY'
    WHEN c.contract_type = 'hourly' THEN 'HOURLY_RATE'
    ELSE 'MONTHLY_SALARY'
  END,
  c.base_rate,
  c.start_date,
  c.end_date
FROM employees e
JOIN contracts c ON e.id = c.employee_id
WHERE c.is_active = 1;
