-- 008_architecture_module3.sql
-- Module 3: Periods and Accruals
-- Based on payroll_system_architecture.md

PRAGMA foreign_keys = ON;

-- 3.1 calculation_periods - Calculation periods
CREATE TABLE IF NOT EXISTS calculation_periods (
  id                     INTEGER PRIMARY KEY AUTOINCREMENT,
  period_code            TEXT NOT NULL UNIQUE,
  period_name            TEXT NOT NULL,
  start_date             DATE NOT NULL,
  end_date               DATE NOT NULL,
  period_type            TEXT NOT NULL, -- monthly, weekly, custom
  organizational_unit_id INTEGER, -- NULL = whole company
  employee_id            INTEGER, -- NULL = all employees
  status                 TEXT NOT NULL DEFAULT 'draft', -- draft, in_review, approved, cancelled
  created_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by             TEXT,
  FOREIGN KEY (organizational_unit_id) REFERENCES org_units(id),
  FOREIGN KEY (employee_id) REFERENCES employees(id)
);

CREATE INDEX IF NOT EXISTS idx_calculation_periods_code
  ON calculation_periods(period_code);

CREATE INDEX IF NOT EXISTS idx_calculation_periods_dates
  ON calculation_periods(start_date, end_date);

CREATE INDEX IF NOT EXISTS idx_calculation_periods_status
  ON calculation_periods(status);


-- 3.2 accrual_documents - Accrual documents
CREATE TABLE IF NOT EXISTS accrual_documents (
  id                     INTEGER PRIMARY KEY AUTOINCREMENT,
  document_number        TEXT NOT NULL UNIQUE,
  period_id              INTEGER NOT NULL,
  template_id            INTEGER NOT NULL, -- which template was used
  organizational_unit_id INTEGER,
  employee_id            INTEGER,
  status                 TEXT NOT NULL DEFAULT 'draft', -- draft, in_review, approved, cancelled
  calculation_date       DATETIME,
  approved_date          DATETIME,
  approved_by            TEXT,
  cancelled_date         DATETIME,
  cancelled_by           TEXT,
  created_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by             TEXT,
  FOREIGN KEY (period_id) REFERENCES calculation_periods(id),
  FOREIGN KEY (template_id) REFERENCES calculation_templates(id),
  FOREIGN KEY (organizational_unit_id) REFERENCES org_units(id),
  FOREIGN KEY (employee_id) REFERENCES employees(id)
);

CREATE INDEX IF NOT EXISTS idx_accrual_documents_number
  ON accrual_documents(document_number);

CREATE INDEX IF NOT EXISTS idx_accrual_documents_period
  ON accrual_documents(period_id);

CREATE INDEX IF NOT EXISTS idx_accrual_documents_status
  ON accrual_documents(status);


-- 3.3 accrual_results - Accrual results (immutable)
CREATE TABLE IF NOT EXISTS accrual_results (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  document_id       INTEGER NOT NULL,
  employee_id       INTEGER NOT NULL,
  rule_id           INTEGER NOT NULL, -- which rule was applied
  rule_code         TEXT NOT NULL, -- rule code for history
  amount            INTEGER NOT NULL, -- in minor units (kopiyky)
  calculation_base  INTEGER, -- calculation base if any
  currency          TEXT NOT NULL DEFAULT 'UAH',
  status            TEXT NOT NULL DEFAULT 'active', -- active, cancelled
  created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (document_id) REFERENCES accrual_documents(id),
  FOREIGN KEY (employee_id) REFERENCES employees(id),
  FOREIGN KEY (rule_id) REFERENCES calculation_rules(id)
);

CREATE INDEX IF NOT EXISTS idx_accrual_results_document
  ON accrual_results(document_id);

CREATE INDEX IF NOT EXISTS idx_accrual_results_employee
  ON accrual_results(employee_id);

CREATE INDEX IF NOT EXISTS idx_accrual_results_status
  ON accrual_results(status);


-- 3.4 change_requests - Change requests for documents
CREATE TABLE IF NOT EXISTS change_requests (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  request_number TEXT NOT NULL UNIQUE,
  document_id    INTEGER NOT NULL, -- which document to change
  reason         TEXT NOT NULL,
  requested_by   TEXT NOT NULL,
  request_date   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status         TEXT NOT NULL DEFAULT 'pending', -- pending, approved, rejected
  approved_by    TEXT,
  approved_date  DATETIME,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (document_id) REFERENCES accrual_documents(id)
);

CREATE INDEX IF NOT EXISTS idx_change_requests_number
  ON change_requests(request_number);

CREATE INDEX IF NOT EXISTS idx_change_requests_document
  ON change_requests(document_id);

CREATE INDEX IF NOT EXISTS idx_change_requests_status
  ON change_requests(status);
