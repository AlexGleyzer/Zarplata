-- 001_init.sql
-- Початкова схема бази Зарплати

PRAGMA foreign_keys = ON;

-- Працівники
CREATE TABLE IF NOT EXISTS employees (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  full_name       TEXT NOT NULL,
  tax_id          TEXT,
  position        TEXT,
  category        TEXT NOT NULL DEFAULT 'default',
  start_date      DATE,
  end_date        DATE,
  meta            TEXT
);

CREATE INDEX IF NOT EXISTS idx_employees_category
  ON employees(category);


-- Розрахункові періоди
CREATE TABLE IF NOT EXISTS pay_periods (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  year        INTEGER NOT NULL,
  month       INTEGER NOT NULL,
  status      TEXT NOT NULL DEFAULT 'draft',
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(year, month)
);


-- Нарахування / утримання
CREATE TABLE IF NOT EXISTS pay_records (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  employee_id   INTEGER NOT NULL,
  period_id     INTEGER NOT NULL,
  type          TEXT NOT NULL,
  direction     TEXT NOT NULL,
  amount        REAL NOT NULL,
  meta          TEXT,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (employee_id) REFERENCES employees(id),
  FOREIGN KEY (period_id)  REFERENCES pay_periods(id)
);

CREATE INDEX IF NOT EXISTS idx_pay_records_employee_period
  ON pay_records(employee_id, period_id);

CREATE INDEX IF NOT EXISTS idx_pay_records_period
  ON pay_records(period_id);

CREATE INDEX IF NOT EXISTS idx_pay_records_type
  ON pay_records(type);


-- Правила нарахувань / податків
CREATE TABLE IF NOT EXISTS pay_rules (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  code               TEXT NOT NULL,
  kind               TEXT NOT NULL,
  employee_category  TEXT NOT NULL DEFAULT 'any',
  valid_from         DATE NOT NULL,
  valid_to           DATE,
  base_type          TEXT NOT NULL,
  formula_type       TEXT NOT NULL,
  rate               REAL,
  amount             REAL,
  formula_dsl        TEXT,
  description        TEXT,
  created_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_pay_rules_code
  ON pay_rules(code);

CREATE INDEX IF NOT EXISTS idx_pay_rules_valid
  ON pay_rules(valid_from, valid_to);


-- Текстові правки правил (для бухгалтера)
CREATE TABLE IF NOT EXISTS pay_rule_edits (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  pay_rule_id    INTEGER,
  human_text     TEXT NOT NULL,
  generated_dsl  TEXT,
  status         TEXT NOT NULL DEFAULT 'draft',
  created_by     TEXT,
  reviewed_by    TEXT,
  review_comment TEXT,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reviewed_at    DATETIME,
  FOREIGN KEY (pay_rule_id) REFERENCES pay_rules(id)
);

CREATE INDEX IF NOT EXISTS idx_pay_rule_edits_status
  ON pay_rule_edits(status);
