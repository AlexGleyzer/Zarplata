-- 003_schema_align.sql
-- Align schema strictly with DB_SCHEMA.md

PRAGMA foreign_keys = OFF;

-- Drop legacy tables not in DB_SCHEMA.md
DROP TABLE IF EXISTS pay_rule_edits;
DROP TABLE IF EXISTS pay_rules;
DROP TABLE IF EXISTS pay_records;
DROP TABLE IF EXISTS pay_periods;

-- Drop incorrect domain tables created earlier
DROP TABLE IF EXISTS employee_status_history;
DROP TABLE IF EXISTS employee_category_history;
DROP TABLE IF EXISTS employee_flags_history;
DROP TABLE IF EXISTS calculation_bases;
DROP TABLE IF EXISTS payment_links;
DROP TABLE IF EXISTS system_meta;
DROP TABLE IF EXISTS rule_versions;
DROP TABLE IF EXISTS accrual_parts;
DROP TABLE IF EXISTS accrual_operations;
DROP TABLE IF EXISTS payment_operations;
DROP TABLE IF EXISTS accrual_types;

-- Rebuild employees to match DB_SCHEMA.md
ALTER TABLE employees RENAME TO employees_legacy;

CREATE TABLE IF NOT EXISTS employees (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  code       TEXT UNIQUE,
  full_name  TEXT NOT NULL,
  tax_id     TEXT,
  hired_at   DATE,
  fired_at   DATE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO employees (code, full_name, tax_id, hired_at, fired_at, created_at, updated_at)
SELECT NULL AS code,
       full_name,
       tax_id,
       start_date,
       end_date,
       CURRENT_TIMESTAMP,
       CURRENT_TIMESTAMP
FROM employees_legacy;

-- Employee categories history
CREATE TABLE IF NOT EXISTS employee_categories_history (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  employee_id   INTEGER NOT NULL,
  category_code TEXT NOT NULL,
  valid_from    DATE NOT NULL,
  valid_to      DATE,
  comment       TEXT,
  FOREIGN KEY (employee_id) REFERENCES employees(id)
);

CREATE INDEX IF NOT EXISTS idx_employee_categories_history_employee
  ON employee_categories_history(employee_id, category_code, valid_from, valid_to);

-- Accrual types
CREATE TABLE IF NOT EXISTS accrual_types (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  code       TEXT NOT NULL UNIQUE,
  name       TEXT NOT NULL,
  direction  TEXT NOT NULL,
  category   TEXT NOT NULL,
  is_active  INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_accrual_types_code
  ON accrual_types(code);

-- Rule versions
CREATE TABLE IF NOT EXISTS rule_versions (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  accrual_type_id     INTEGER NOT NULL,
  valid_from          DATE NOT NULL,
  valid_to            DATE,
  base_kind           TEXT NOT NULL,
  human_description   TEXT,
  formula_dsl         TEXT,
  flags_json          TEXT,
  FOREIGN KEY (accrual_type_id) REFERENCES accrual_types(id)
);

CREATE INDEX IF NOT EXISTS idx_rule_versions_type_valid
  ON rule_versions(accrual_type_id, valid_from, valid_to);

-- Base values (global)
CREATE TABLE IF NOT EXISTS base_values (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  base_code  TEXT NOT NULL,
  value      INTEGER NOT NULL,
  valid_from DATE NOT NULL,
  valid_to   DATE,
  comment    TEXT
);

CREATE INDEX IF NOT EXISTS idx_base_values_code_valid
  ON base_values(base_code, valid_from, valid_to);

-- Employee bases (personal)
CREATE TABLE IF NOT EXISTS employee_bases (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  employee_id INTEGER NOT NULL,
  base_code   TEXT NOT NULL,
  value       INTEGER NOT NULL,
  valid_from  DATE NOT NULL,
  valid_to    DATE,
  FOREIGN KEY (employee_id) REFERENCES employees(id)
);

CREATE INDEX IF NOT EXISTS idx_employee_bases_employee
  ON employee_bases(employee_id, base_code, valid_from, valid_to);

-- Accrual operations
CREATE TABLE IF NOT EXISTS accrual_operations (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  operation_code  TEXT NOT NULL UNIQUE,
  employee_id     INTEGER NOT NULL,
  accrual_type_id INTEGER NOT NULL,
  rule_version_id INTEGER NOT NULL,
  period_from     DATE NOT NULL,
  period_to       DATE NOT NULL,
  total_amount    INTEGER NOT NULL,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by      TEXT,
  FOREIGN KEY (employee_id) REFERENCES employees(id),
  FOREIGN KEY (accrual_type_id) REFERENCES accrual_types(id),
  FOREIGN KEY (rule_version_id) REFERENCES rule_versions(id)
);

CREATE INDEX IF NOT EXISTS idx_accrual_operations_employee_period
  ON accrual_operations(employee_id, period_from, period_to);

-- Accrual parts
CREATE TABLE IF NOT EXISTS accrual_parts (
  id                   INTEGER PRIMARY KEY AUTOINCREMENT,
  accrual_operation_id INTEGER NOT NULL,
  part_from            DATE NOT NULL,
  part_to              DATE NOT NULL,
  base_snapshot_json   TEXT,
  amount               INTEGER NOT NULL,
  calc_details_json    TEXT,
  FOREIGN KEY (accrual_operation_id) REFERENCES accrual_operations(id)
);

CREATE INDEX IF NOT EXISTS idx_accrual_parts_operation
  ON accrual_parts(accrual_operation_id, part_from, part_to);

-- Payment operations
CREATE TABLE IF NOT EXISTS payment_operations (
  id                    INTEGER PRIMARY KEY AUTOINCREMENT,
  payment_code          TEXT,
  payment_date          DATE NOT NULL,
  total_amount          INTEGER NOT NULL,
  recipient_type        TEXT,
  recipient_employee_id INTEGER,
  note                  TEXT,
  created_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by            TEXT,
  FOREIGN KEY (recipient_employee_id) REFERENCES employees(id)
);

-- Payment links
CREATE TABLE IF NOT EXISTS payment_accrual_links (
  id                   INTEGER PRIMARY KEY AUTOINCREMENT,
  payment_id           INTEGER NOT NULL,
  accrual_operation_id INTEGER NOT NULL,
  amount               INTEGER NOT NULL,
  FOREIGN KEY (payment_id) REFERENCES payment_operations(id),
  FOREIGN KEY (accrual_operation_id) REFERENCES accrual_operations(id)
);

CREATE INDEX IF NOT EXISTS idx_payment_accrual_links_payment
  ON payment_accrual_links(payment_id);

CREATE INDEX IF NOT EXISTS idx_payment_accrual_links_accrual
  ON payment_accrual_links(accrual_operation_id);

-- Schema metadata
CREATE TABLE IF NOT EXISTS schema_meta (
  id             INTEGER PRIMARY KEY CHECK (id = 1),
  schema_version INTEGER NOT NULL,
  updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

PRAGMA foreign_keys = ON;
