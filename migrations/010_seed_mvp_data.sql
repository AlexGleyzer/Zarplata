-- Migration 010: Seed MVP Data
-- Calculation rules, templates, contracts, and base values

-- Base values (minimum wage, living wage)
INSERT INTO base_values (code, name, value, effective_from) VALUES
('MIN_WAGE', 'Мінімальна заробітна плата', 7100.00, '2024-01-01'),
('LIVING_WAGE', 'Прожитковий мінімум', 2920.00, '2024-01-01');

-- Accrual types
INSERT INTO accrual_types (code, name, type, description) VALUES
('SALARY', 'Основна заробітна плата', 'accrual', 'Нарахування основної зарплати'),
('PIT', 'ПДФО', 'deduction', 'Податок на доходи фізичних осіб (18%)'),
('WAR_TAX', 'Військовий збір', 'deduction', 'Військовий збір (1.5%)');

-- Calculation rules
INSERT INTO calculation_rules (code, name, description, rule_type, sql_formula, parameters) VALUES
('BASE_SALARY', 'Основна зарплата', 'Нарахування основної заробітної плати на основі окладу або погодинної ставки', 'accrual',
'SELECT
  e.id as employee_id,
  CASE
    WHEN c.contract_type = ''salary'' THEN c.base_amount
    WHEN c.contract_type = ''hourly'' THEN c.base_amount * COALESCE(
      (SELECT SUM(hours_worked) FROM timesheets t
       WHERE t.employee_id = e.id
       AND t.work_date BETWEEN :period_start AND :period_end), 0)
  END as amount,
  c.base_amount as base_amount,
  c.contract_type as rate_type
FROM employees e
JOIN contracts c ON c.employee_id = e.id AND c.status = ''active''
WHERE e.status = ''active''',
'{"description": "Розрахунок базової зарплати"}'),

('PIT', 'ПДФО (18%)', 'Утримання податку на доходи фізичних осіб', 'tax',
'SELECT
  ar.employee_id,
  ROUND(SUM(ar.amount) * 0.18, 2) as amount,
  SUM(ar.amount) as base_amount,
  0.18 as rate
FROM accrual_results ar
WHERE ar.document_id = :document_id
  AND ar.accrual_type = ''accrual''
  AND ar.status = ''active''
GROUP BY ar.employee_id',
'{"rate": 0.18, "description": "18% від нарахованого доходу"}'),

('WAR_TAX', 'Військовий збір (1.5%)', 'Утримання військового збору', 'tax',
'SELECT
  ar.employee_id,
  ROUND(SUM(ar.amount) * 0.015, 2) as amount,
  SUM(ar.amount) as base_amount,
  0.015 as rate
FROM accrual_results ar
WHERE ar.document_id = :document_id
  AND ar.accrual_type = ''accrual''
  AND ar.status = ''active''
GROUP BY ar.employee_id',
'{"rate": 0.015, "description": "1.5% від нарахованого доходу"}');

-- Calculation template
INSERT INTO calculation_templates (code, name, description) VALUES
('MONTHLY_SALARY', 'Місячна зарплата', 'Стандартний шаблон для розрахунку місячної зарплати з податками');

-- Template rules (execution order)
INSERT INTO template_rules (template_id, rule_id, execution_order, is_required) VALUES
((SELECT id FROM calculation_templates WHERE code = 'MONTHLY_SALARY'),
 (SELECT id FROM calculation_rules WHERE code = 'BASE_SALARY'), 1, 1),
((SELECT id FROM calculation_templates WHERE code = 'MONTHLY_SALARY'),
 (SELECT id FROM calculation_rules WHERE code = 'PIT'), 2, 1),
((SELECT id FROM calculation_templates WHERE code = 'MONTHLY_SALARY'),
 (SELECT id FROM calculation_rules WHERE code = 'WAR_TAX'), 3, 1);

-- Contracts for employees
-- Salary employees (20,000 UAH/month)
INSERT INTO contracts (employee_id, contract_number, contract_type, start_date, base_amount) VALUES
((SELECT id FROM employees WHERE employee_code = 'EMP001'), 'CTR-2023-001', 'salary', '2023-01-15', 20000.00),
((SELECT id FROM employees WHERE employee_code = 'EMP002'), 'CTR-2023-002', 'salary', '2023-02-01', 20000.00),
((SELECT id FROM employees WHERE employee_code = 'EMP006'), 'CTR-2023-006', 'salary', '2023-06-15', 20000.00),
((SELECT id FROM employees WHERE employee_code = 'EMP008'), 'CTR-2023-008', 'salary', '2023-08-10', 20000.00);

-- Salary employees (18,000 UAH/month)
INSERT INTO contracts (employee_id, contract_number, contract_type, start_date, base_amount) VALUES
((SELECT id FROM employees WHERE employee_code = 'EMP005'), 'CTR-2023-005', 'salary', '2023-05-20', 18000.00),
((SELECT id FROM employees WHERE employee_code = 'EMP007'), 'CTR-2023-007', 'salary', '2023-07-01', 18000.00);

-- Hourly employees (150 UAH/hour)
INSERT INTO contracts (employee_id, contract_number, contract_type, start_date, base_amount) VALUES
((SELECT id FROM employees WHERE employee_code = 'EMP003'), 'CTR-2023-003', 'hourly', '2023-03-10', 150.00),
((SELECT id FROM employees WHERE employee_code = 'EMP004'), 'CTR-2023-004', 'hourly', '2023-04-05', 150.00),
((SELECT id FROM employees WHERE employee_code = 'EMP009'), 'CTR-2023-009', 'hourly', '2023-09-05', 150.00),
((SELECT id FROM employees WHERE employee_code = 'EMP010'), 'CTR-2023-010', 'hourly', '2023-10-20', 150.00);

-- Employee bases (personal salary records)
INSERT INTO employee_bases (employee_id, base_type, value, effective_from) VALUES
((SELECT id FROM employees WHERE employee_code = 'EMP001'), 'salary', 20000.00, '2023-01-15'),
((SELECT id FROM employees WHERE employee_code = 'EMP002'), 'salary', 20000.00, '2023-02-01'),
((SELECT id FROM employees WHERE employee_code = 'EMP003'), 'hourly_rate', 150.00, '2023-03-10'),
((SELECT id FROM employees WHERE employee_code = 'EMP004'), 'hourly_rate', 150.00, '2023-04-05'),
((SELECT id FROM employees WHERE employee_code = 'EMP005'), 'salary', 18000.00, '2023-05-20'),
((SELECT id FROM employees WHERE employee_code = 'EMP006'), 'salary', 20000.00, '2023-06-15'),
((SELECT id FROM employees WHERE employee_code = 'EMP007'), 'salary', 18000.00, '2023-07-01'),
((SELECT id FROM employees WHERE employee_code = 'EMP008'), 'salary', 20000.00, '2023-08-10'),
((SELECT id FROM employees WHERE employee_code = 'EMP009'), 'hourly_rate', 150.00, '2023-09-05'),
((SELECT id FROM employees WHERE employee_code = 'EMP010'), 'hourly_rate', 150.00, '2023-10-20');

-- Update schema version
INSERT INTO schema_meta (version, description) VALUES ('1.1.0', 'MVP data seeded');
