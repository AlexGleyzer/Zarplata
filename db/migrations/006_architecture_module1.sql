-- 006_architecture_module1.sql
-- Module 1: Company Structure and Employees
-- Based on payroll_system_architecture.md

PRAGMA foreign_keys = ON;

-- 1.3 contracts - Employee contracts
CREATE TABLE IF NOT EXISTS contracts (
  id                     INTEGER PRIMARY KEY AUTOINCREMENT,
  employee_id            INTEGER NOT NULL,
  contract_number        TEXT NOT NULL,
  contract_type          TEXT NOT NULL, -- hourly, salary, piecework, task_based
  start_date             DATE NOT NULL,
  end_date               DATE,
  base_rate              INTEGER NOT NULL, -- in minor units (kopiyky)
  currency               TEXT NOT NULL DEFAULT 'UAH',
  organizational_unit_id INTEGER,
  is_active              INTEGER NOT NULL DEFAULT 1,
  created_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (employee_id) REFERENCES employees(id),
  FOREIGN KEY (organizational_unit_id) REFERENCES org_units(id)
);

CREATE INDEX IF NOT EXISTS idx_contracts_employee
  ON contracts(employee_id);

CREATE INDEX IF NOT EXISTS idx_contracts_org_unit
  ON contracts(organizational_unit_id);

CREATE INDEX IF NOT EXISTS idx_contracts_active
  ON contracts(is_active, start_date, end_date);


-- 1.4 calculation_rules - Calculation rules with SQL code
CREATE TABLE IF NOT EXISTS calculation_rules (
  id                     INTEGER PRIMARY KEY AUTOINCREMENT,
  organizational_unit_id INTEGER, -- NULL = global rule
  code                   TEXT NOT NULL,
  name                   TEXT NOT NULL,
  description            TEXT,
  sql_code               TEXT NOT NULL, -- SQL code to execute
  rule_type              TEXT NOT NULL, -- accrual, deduction, tax
  is_active              INTEGER NOT NULL DEFAULT 1,
  created_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by             TEXT,
  FOREIGN KEY (organizational_unit_id) REFERENCES org_units(id)
);

CREATE INDEX IF NOT EXISTS idx_calculation_rules_code
  ON calculation_rules(code);

CREATE INDEX IF NOT EXISTS idx_calculation_rules_org_unit
  ON calculation_rules(organizational_unit_id);

CREATE INDEX IF NOT EXISTS idx_calculation_rules_active
  ON calculation_rules(is_active);


-- 1.5 calculation_templates - Calculation templates
CREATE TABLE IF NOT EXISTS calculation_templates (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  code        TEXT NOT NULL UNIQUE,
  name        TEXT NOT NULL,
  description TEXT,
  is_active   INTEGER NOT NULL DEFAULT 1,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_calculation_templates_code
  ON calculation_templates(code);


-- 1.6 template_rules - Link between templates and rules
CREATE TABLE IF NOT EXISTS template_rules (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  template_id     INTEGER NOT NULL,
  rule_id         INTEGER NOT NULL,
  execution_order INTEGER NOT NULL, -- 1, 2, 3...
  is_active       INTEGER NOT NULL DEFAULT 1,
  FOREIGN KEY (template_id) REFERENCES calculation_templates(id),
  FOREIGN KEY (rule_id) REFERENCES calculation_rules(id)
);

CREATE INDEX IF NOT EXISTS idx_template_rules_template
  ON template_rules(template_id, execution_order);

CREATE INDEX IF NOT EXISTS idx_template_rules_rule
  ON template_rules(rule_id);
