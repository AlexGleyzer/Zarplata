-- 009_architecture_module4.sql
-- Module 4: Payments
-- Based on payroll_system_architecture.md

PRAGMA foreign_keys = ON;

-- 4.1 payment_rules - Payment formation rules
CREATE TABLE IF NOT EXISTS payment_rules (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  code             TEXT NOT NULL UNIQUE,
  name             TEXT NOT NULL,
  description      TEXT,
  rule_type        TEXT NOT NULL, -- individual, grouped, bank_statement
  grouping_logic   TEXT, -- JSON with grouping logic
  recipient_type   TEXT NOT NULL, -- employee_card, tax_authority, bank_special
  is_active        INTEGER NOT NULL DEFAULT 1,
  created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_payment_rules_code
  ON payment_rules(code);

CREATE INDEX IF NOT EXISTS idx_payment_rules_type
  ON payment_rules(rule_type, recipient_type);


-- 4.2 payment_documents - Payment documents
CREATE TABLE IF NOT EXISTS payment_documents (
  id                     INTEGER PRIMARY KEY AUTOINCREMENT,
  document_number        TEXT NOT NULL UNIQUE,
  period_id              INTEGER NOT NULL,
  payment_rule_id        INTEGER NOT NULL, -- which rule was applied
  organizational_unit_id INTEGER,
  employee_id            INTEGER,
  total_amount           INTEGER NOT NULL, -- in minor units
  currency               TEXT NOT NULL DEFAULT 'UAH',
  payment_date           DATE, -- planned date
  actual_payment_date    DATE, -- actual date
  status                 TEXT NOT NULL DEFAULT 'draft', -- draft, in_review, approved, executed, cancelled
  created_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by             TEXT,
  approved_by            TEXT,
  executed_by            TEXT,
  FOREIGN KEY (period_id) REFERENCES calculation_periods(id),
  FOREIGN KEY (payment_rule_id) REFERENCES payment_rules(id),
  FOREIGN KEY (organizational_unit_id) REFERENCES org_units(id),
  FOREIGN KEY (employee_id) REFERENCES employees(id)
);

CREATE INDEX IF NOT EXISTS idx_payment_documents_number
  ON payment_documents(document_number);

CREATE INDEX IF NOT EXISTS idx_payment_documents_period
  ON payment_documents(period_id);

CREATE INDEX IF NOT EXISTS idx_payment_documents_status
  ON payment_documents(status);


-- 4.3 payment_items - Payment items
CREATE TABLE IF NOT EXISTS payment_items (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  payment_document_id INTEGER NOT NULL,
  accrual_result_id   INTEGER NOT NULL, -- link to accrual
  employee_id         INTEGER NOT NULL,
  amount              INTEGER NOT NULL, -- in minor units
  currency            TEXT NOT NULL DEFAULT 'UAH',
  recipient_account   TEXT, -- recipient account
  purpose             TEXT, -- payment purpose
  status              TEXT NOT NULL DEFAULT 'pending', -- pending, executed, cancelled
  FOREIGN KEY (payment_document_id) REFERENCES payment_documents(id),
  FOREIGN KEY (accrual_result_id) REFERENCES accrual_results(id),
  FOREIGN KEY (employee_id) REFERENCES employees(id)
);

CREATE INDEX IF NOT EXISTS idx_payment_items_document
  ON payment_items(payment_document_id);

CREATE INDEX IF NOT EXISTS idx_payment_items_accrual
  ON payment_items(accrual_result_id);

CREATE INDEX IF NOT EXISTS idx_payment_items_employee
  ON payment_items(employee_id);


-- 4.4 bank_statements - Bank statements
CREATE TABLE IF NOT EXISTS bank_statements (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  payment_document_id INTEGER NOT NULL,
  statement_number    TEXT NOT NULL,
  file_path           TEXT, -- path to generated file (Excel/PDF)
  bank_code           TEXT,
  created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (payment_document_id) REFERENCES payment_documents(id)
);

CREATE INDEX IF NOT EXISTS idx_bank_statements_document
  ON bank_statements(payment_document_id);

CREATE INDEX IF NOT EXISTS idx_bank_statements_number
  ON bank_statements(statement_number);
