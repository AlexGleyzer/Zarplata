-- 002_domain_core.sql
-- Core domain tables aligned with DOMAIN.md

PRAGMA foreign_keys = ON;

-- Accrual types (classification of operations)
CREATE TABLE IF NOT EXISTS accrual_types (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  code        TEXT NOT NULL UNIQUE,
  name        TEXT NOT NULL,
  direction   TEXT NOT NULL,
  category    TEXT NOT NULL,
  description TEXT,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_accrual_types_code
  ON accrual_types(code);


-- Rule versions for each accrual type
CREATE TABLE IF NOT EXISTS rule_versions (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  accrual_type_id  INTEGER NOT NULL,
  valid_from       DATE NOT NULL,
  valid_to         DATE,
  base_type        TEXT NOT NULL,
  algorithm_text   TEXT,
  formula_dsl      TEXT,
  min_amount       REAL,
  max_amount       REAL,
  includes_in_base INTEGER NOT NULL DEFAULT 1,
  created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (accrual_type_id) REFERENCES accrual_types(id)
);

CREATE INDEX IF NOT EXISTS idx_rule_versions_type_valid
  ON rule_versions(accrual_type_id, valid_from, valid_to);


-- Employee status history
CREATE TABLE IF NOT EXISTS employee_status_history (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  employee_id INTEGER NOT NULL,
  status      TEXT NOT NULL,
  valid_from  DATE NOT NULL,
  valid_to    DATE,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (employee_id) REFERENCES employees(id)
);

CREATE INDEX IF NOT EXISTS idx_employee_status_history_employee
  ON employee_status_history(employee_id, valid_from, valid_to);


-- Employee categories history (e.g. full-time, minor, disabled)
CREATE TABLE IF NOT EXISTS employee_category_history (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  employee_id INTEGER NOT NULL,
  category    TEXT NOT NULL,
  valid_from  DATE NOT NULL,
  valid_to    DATE,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (employee_id) REFERENCES employees(id)
);

CREATE INDEX IF NOT EXISTS idx_employee_category_history_employee
  ON employee_category_history(employee_id, category, valid_from, valid_to);


-- Employee flags history for additional attributes
CREATE TABLE IF NOT EXISTS employee_flags_history (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  employee_id INTEGER NOT NULL,
  flag_key    TEXT NOT NULL,
  flag_value  TEXT NOT NULL,
  valid_from  DATE NOT NULL,
  valid_to    DATE,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (employee_id) REFERENCES employees(id)
);

CREATE INDEX IF NOT EXISTS idx_employee_flags_history_employee
  ON employee_flags_history(employee_id, flag_key, valid_from, valid_to);


-- Calculation / tax bases
CREATE TABLE IF NOT EXISTS calculation_bases (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  base_type  TEXT NOT NULL,
  scope_type TEXT NOT NULL,
  scope_ref  TEXT,
  value      REAL NOT NULL,
  unit       TEXT,
  valid_from DATE NOT NULL,
  valid_to   DATE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_calculation_bases_valid
  ON calculation_bases(base_type, scope_type, scope_ref, valid_from, valid_to);


-- Accrual operations (one debt event)
CREATE TABLE IF NOT EXISTS accrual_operations (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  operation_code   TEXT NOT NULL UNIQUE,
  employee_id      INTEGER,
  accrual_type_id  INTEGER NOT NULL,
  rule_version_id  INTEGER NOT NULL,
  period_start     DATE NOT NULL,
  period_end       DATE NOT NULL,
  total_amount     REAL NOT NULL,
  beneficiary_type TEXT NOT NULL,
  beneficiary_ref  TEXT,
  created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  meta             TEXT,
  FOREIGN KEY (employee_id) REFERENCES employees(id),
  FOREIGN KEY (accrual_type_id) REFERENCES accrual_types(id),
  FOREIGN KEY (rule_version_id) REFERENCES rule_versions(id)
);

CREATE INDEX IF NOT EXISTS idx_accrual_operations_employee_period
  ON accrual_operations(employee_id, period_start, period_end);


-- Accrual parts (subperiods)
CREATE TABLE IF NOT EXISTS accrual_parts (
  id                   INTEGER PRIMARY KEY AUTOINCREMENT,
  accrual_operation_id INTEGER NOT NULL,
  part_start           DATE NOT NULL,
  part_end             DATE NOT NULL,
  base_payload         TEXT,
  amount               REAL NOT NULL,
  created_at           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (accrual_operation_id) REFERENCES accrual_operations(id)
);

CREATE INDEX IF NOT EXISTS idx_accrual_parts_operation
  ON accrual_parts(accrual_operation_id, part_start, part_end);


-- Payment operations
CREATE TABLE IF NOT EXISTS payment_operations (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  payment_date   DATE NOT NULL,
  amount         REAL NOT NULL,
  recipient_type TEXT NOT NULL,
  recipient_ref  TEXT,
  method         TEXT,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  meta           TEXT
);


-- Link payments to accrual operations (partial payments allowed)
CREATE TABLE IF NOT EXISTS payment_links (
  id                   INTEGER PRIMARY KEY AUTOINCREMENT,
  payment_id           INTEGER NOT NULL,
  accrual_operation_id INTEGER NOT NULL,
  amount               REAL NOT NULL,
  created_at           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (payment_id) REFERENCES payment_operations(id),
  FOREIGN KEY (accrual_operation_id) REFERENCES accrual_operations(id)
);

CREATE INDEX IF NOT EXISTS idx_payment_links_payment
  ON payment_links(payment_id);

CREATE INDEX IF NOT EXISTS idx_payment_links_accrual
  ON payment_links(accrual_operation_id);


-- System metadata for schema versioning
CREATE TABLE IF NOT EXISTS system_meta (
  id             INTEGER PRIMARY KEY CHECK (id = 1),
  schema_version INTEGER NOT NULL,
  updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
