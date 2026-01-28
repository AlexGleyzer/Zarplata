-- Migration 005: Seed Organizational Units
-- Company structure: Futura Industries

-- Company level
INSERT INTO org_units (code, name, unit_type, parent_id) VALUES
('FUTURA', 'Futura Industries', 'company', NULL);

-- Departments
INSERT INTO org_units (code, name, unit_type, parent_id) VALUES
('SALES', 'Sales Department', 'department', (SELECT id FROM org_units WHERE code = 'FUTURA')),
('ENG', 'Engineering Department', 'department', (SELECT id FROM org_units WHERE code = 'FUTURA')),
('OPS', 'Operations Department', 'department', (SELECT id FROM org_units WHERE code = 'FUTURA'));

-- Teams under Sales
INSERT INTO org_units (code, name, unit_type, parent_id) VALUES
('SALES_EAST', 'Sales East', 'team', (SELECT id FROM org_units WHERE code = 'SALES')),
('SALES_WEST', 'Sales West', 'team', (SELECT id FROM org_units WHERE code = 'SALES'));

-- Teams under Engineering
INSERT INTO org_units (code, name, unit_type, parent_id) VALUES
('PLATFORM', 'Platform Team', 'team', (SELECT id FROM org_units WHERE code = 'ENG')),
('PRODUCT', 'Product Team', 'team', (SELECT id FROM org_units WHERE code = 'ENG'));

-- Teams under Operations
INSERT INTO org_units (code, name, unit_type, parent_id) VALUES
('FINANCE', 'Finance Team', 'team', (SELECT id FROM org_units WHERE code = 'OPS')),
('HR', 'HR Team', 'team', (SELECT id FROM org_units WHERE code = 'OPS'));

-- Assign employees to teams
INSERT INTO employee_org_unit_history (employee_id, org_unit_id, position, start_date, is_primary) VALUES
((SELECT id FROM employees WHERE employee_code = 'EMP001'), (SELECT id FROM org_units WHERE code = 'SALES_EAST'), 'Sales Manager', '2023-01-15', 1),
((SELECT id FROM employees WHERE employee_code = 'EMP002'), (SELECT id FROM org_units WHERE code = 'SALES_EAST'), 'Sales Representative', '2023-02-01', 1),
((SELECT id FROM employees WHERE employee_code = 'EMP003'), (SELECT id FROM org_units WHERE code = 'SALES_WEST'), 'Sales Representative', '2023-03-10', 1),
((SELECT id FROM employees WHERE employee_code = 'EMP004'), (SELECT id FROM org_units WHERE code = 'SALES_WEST'), 'Sales Representative', '2023-04-05', 1),
((SELECT id FROM employees WHERE employee_code = 'EMP005'), (SELECT id FROM org_units WHERE code = 'PLATFORM'), 'Senior Developer', '2023-05-20', 1),
((SELECT id FROM employees WHERE employee_code = 'EMP006'), (SELECT id FROM org_units WHERE code = 'PLATFORM'), 'Developer', '2023-06-15', 1),
((SELECT id FROM employees WHERE employee_code = 'EMP007'), (SELECT id FROM org_units WHERE code = 'PRODUCT'), 'Product Manager', '2023-07-01', 1),
((SELECT id FROM employees WHERE employee_code = 'EMP008'), (SELECT id FROM org_units WHERE code = 'PRODUCT'), 'Developer', '2023-08-10', 1),
((SELECT id FROM employees WHERE employee_code = 'EMP009'), (SELECT id FROM org_units WHERE code = 'FINANCE'), 'Accountant', '2023-09-05', 1),
((SELECT id FROM employees WHERE employee_code = 'EMP010'), (SELECT id FROM org_units WHERE code = 'HR'), 'HR Specialist', '2023-10-20', 1);
