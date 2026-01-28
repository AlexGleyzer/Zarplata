-- 007_architecture_module2.sql
-- Module 2: Work Results
-- Based on payroll_system_architecture.md

PRAGMA foreign_keys = ON;

-- 2.1 work_results - Work results
CREATE TABLE IF NOT EXISTS work_results (
  id                     INTEGER PRIMARY KEY AUTOINCREMENT,
  employee_id            INTEGER NOT NULL,
  result_date            DATE NOT NULL,
  result_type            TEXT NOT NULL, -- hours, minutes, pieces, tasks, shifts
  value                  INTEGER NOT NULL, -- numeric value in minor units
  unit                   TEXT NOT NULL, -- unit of measurement
  organizational_unit_id INTEGER NOT NULL,
  status                 TEXT NOT NULL DEFAULT 'draft', -- draft, confirmed, cancelled
  created_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by             TEXT,
  FOREIGN KEY (employee_id) REFERENCES employees(id),
  FOREIGN KEY (organizational_unit_id) REFERENCES org_units(id)
);

CREATE INDEX IF NOT EXISTS idx_work_results_employee_date
  ON work_results(employee_id, result_date);

CREATE INDEX IF NOT EXISTS idx_work_results_status
  ON work_results(status);

CREATE INDEX IF NOT EXISTS idx_work_results_org_unit
  ON work_results(organizational_unit_id, result_date);


-- 2.2 timesheets - Timesheet records
CREATE TABLE IF NOT EXISTS timesheets (
  id                     INTEGER PRIMARY KEY AUTOINCREMENT,
  employee_id            INTEGER NOT NULL,
  work_date              DATE NOT NULL,
  hours_worked           INTEGER NOT NULL DEFAULT 0, -- in minutes
  minutes_worked         INTEGER NOT NULL DEFAULT 0,
  shift_type             TEXT, -- day, night, overtime
  organizational_unit_id INTEGER NOT NULL,
  status                 TEXT NOT NULL DEFAULT 'draft',
  created_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (employee_id) REFERENCES employees(id),
  FOREIGN KEY (organizational_unit_id) REFERENCES org_units(id)
);

CREATE INDEX IF NOT EXISTS idx_timesheets_employee_date
  ON timesheets(employee_id, work_date);

CREATE INDEX IF NOT EXISTS idx_timesheets_status
  ON timesheets(status);

CREATE UNIQUE INDEX IF NOT EXISTS idx_timesheets_unique
  ON timesheets(employee_id, work_date);


-- 2.3 production_results - Production results
CREATE TABLE IF NOT EXISTS production_results (
  id                     INTEGER PRIMARY KEY AUTOINCREMENT,
  employee_id            INTEGER NOT NULL,
  work_date              DATE NOT NULL,
  product_code           TEXT NOT NULL,
  quantity               INTEGER NOT NULL, -- in minor units
  quality_coefficient    REAL NOT NULL DEFAULT 1.0,
  organizational_unit_id INTEGER NOT NULL,
  status                 TEXT NOT NULL DEFAULT 'draft',
  created_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (employee_id) REFERENCES employees(id),
  FOREIGN KEY (organizational_unit_id) REFERENCES org_units(id)
);

CREATE INDEX IF NOT EXISTS idx_production_results_employee_date
  ON production_results(employee_id, work_date);

CREATE INDEX IF NOT EXISTS idx_production_results_product
  ON production_results(product_code);

CREATE INDEX IF NOT EXISTS idx_production_results_status
  ON production_results(status);
