-- 005_org_units_seed.sql
-- Org units tree and employee assignments (3 levels)

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS org_units (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  parent_id  INTEGER,
  code       TEXT NOT NULL UNIQUE,
  name       TEXT NOT NULL,
  unit_type  TEXT NOT NULL,
  valid_from DATE NOT NULL,
  valid_to   DATE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (parent_id) REFERENCES org_units(id)
);

CREATE INDEX IF NOT EXISTS idx_org_units_parent
  ON org_units(parent_id);

CREATE TABLE IF NOT EXISTS employee_org_unit_history (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  employee_id INTEGER NOT NULL,
  org_unit_id INTEGER NOT NULL,
  valid_from  DATE NOT NULL,
  valid_to    DATE,
  comment     TEXT,
  FOREIGN KEY (employee_id) REFERENCES employees(id),
  FOREIGN KEY (org_unit_id) REFERENCES org_units(id)
);

CREATE INDEX IF NOT EXISTS idx_employee_org_unit_history_employee
  ON employee_org_unit_history(employee_id, valid_from, valid_to);

-- Seed org units (3 levels)
INSERT INTO org_units (parent_id, code, name, unit_type, valid_from)
VALUES
  (NULL, 'COMPANY', 'Futura Industries', 'COMPANY', '2020-01-01');

INSERT INTO org_units (parent_id, code, name, unit_type, valid_from)
VALUES
  ((SELECT id FROM org_units WHERE code = 'COMPANY'), 'DEPT_SALES', 'Sales Department', 'DEPARTMENT', '2020-01-01'),
  ((SELECT id FROM org_units WHERE code = 'COMPANY'), 'DEPT_ENGINEERING', 'Engineering Department', 'DEPARTMENT', '2020-01-01'),
  ((SELECT id FROM org_units WHERE code = 'COMPANY'), 'DEPT_OPERATIONS', 'Operations Department', 'DEPARTMENT', '2020-01-01');

INSERT INTO org_units (parent_id, code, name, unit_type, valid_from)
VALUES
  ((SELECT id FROM org_units WHERE code = 'DEPT_SALES'), 'TEAM_SALES_EAST', 'Sales East', 'TEAM', '2020-01-01'),
  ((SELECT id FROM org_units WHERE code = 'DEPT_SALES'), 'TEAM_SALES_WEST', 'Sales West', 'TEAM', '2020-01-01'),
  ((SELECT id FROM org_units WHERE code = 'DEPT_ENGINEERING'), 'TEAM_PLATFORM', 'Platform Team', 'TEAM', '2020-01-01'),
  ((SELECT id FROM org_units WHERE code = 'DEPT_ENGINEERING'), 'TEAM_PRODUCT', 'Product Team', 'TEAM', '2020-01-01'),
  ((SELECT id FROM org_units WHERE code = 'DEPT_OPERATIONS'), 'TEAM_FINANCE', 'Finance Team', 'TEAM', '2020-01-01'),
  ((SELECT id FROM org_units WHERE code = 'DEPT_OPERATIONS'), 'TEAM_HR', 'HR Team', 'TEAM', '2020-01-01');

-- Seed employee assignments
INSERT INTO employee_org_unit_history (employee_id, org_unit_id, valid_from, comment)
VALUES
  ((SELECT id FROM employees WHERE code = 'EMP001'), (SELECT id FROM org_units WHERE code = 'TEAM_PLATFORM'), '2023-02-15', 'Initial assignment'),
  ((SELECT id FROM employees WHERE code = 'EMP002'), (SELECT id FROM org_units WHERE code = 'TEAM_PRODUCT'), '2022-11-01', 'Initial assignment'),
  ((SELECT id FROM employees WHERE code = 'EMP003'), (SELECT id FROM org_units WHERE code = 'TEAM_SALES_EAST'), '2021-06-10', 'Initial assignment'),
  ((SELECT id FROM employees WHERE code = 'EMP004'), (SELECT id FROM org_units WHERE code = 'TEAM_SALES_WEST'), '2020-04-20', 'Initial assignment'),
  ((SELECT id FROM employees WHERE code = 'EMP005'), (SELECT id FROM org_units WHERE code = 'TEAM_FINANCE'), '2019-09-05', 'Initial assignment'),
  ((SELECT id FROM employees WHERE code = 'EMP006'), (SELECT id FROM org_units WHERE code = 'TEAM_PLATFORM'), '2023-07-03', 'Initial assignment'),
  ((SELECT id FROM employees WHERE code = 'EMP007'), (SELECT id FROM org_units WHERE code = 'TEAM_HR'), '2022-01-17', 'Initial assignment'),
  ((SELECT id FROM employees WHERE code = 'EMP008'), (SELECT id FROM org_units WHERE code = 'TEAM_PRODUCT'), '2021-12-08', 'Initial assignment'),
  ((SELECT id FROM employees WHERE code = 'EMP009'), (SELECT id FROM org_units WHERE code = 'TEAM_SALES_EAST'), '2020-03-12', 'Initial assignment'),
  ((SELECT id FROM employees WHERE code = 'EMP010'), (SELECT id FROM org_units WHERE code = 'TEAM_SALES_WEST'), '2018-08-27', 'Initial assignment');
