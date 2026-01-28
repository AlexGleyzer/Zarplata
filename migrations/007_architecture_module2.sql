-- Migration 007: Module 2 - Work Results
-- Timesheets and production results

-- Work results table
CREATE TABLE IF NOT EXISTS work_results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    result_type TEXT NOT NULL CHECK (result_type IN ('timesheet', 'production', 'bonus')),
    value REAL NOT NULL,
    unit TEXT NOT NULL, -- hours, pieces, percent, etc.
    description TEXT,
    status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'approved', 'cancelled')),
    approved_by TEXT,
    approved_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT DEFAULT 'system',
    updated_by TEXT DEFAULT 'system'
);

-- Timesheets table
CREATE TABLE IF NOT EXISTS timesheets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    work_date DATE NOT NULL,
    hours_worked REAL NOT NULL DEFAULT 0,
    hours_overtime REAL DEFAULT 0,
    hours_night REAL DEFAULT 0,
    hours_holiday REAL DEFAULT 0,
    absence_type TEXT CHECK (absence_type IN ('vacation', 'sick', 'unpaid', 'business_trip', NULL)),
    absence_hours REAL DEFAULT 0,
    notes TEXT,
    status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'approved', 'cancelled')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT DEFAULT 'system',
    UNIQUE(employee_id, work_date)
);

-- Production results table
CREATE TABLE IF NOT EXISTS production_results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    product_code TEXT NOT NULL,
    quantity REAL NOT NULL,
    unit TEXT NOT NULL,
    rate REAL NOT NULL,
    total_amount REAL GENERATED ALWAYS AS (quantity * rate) STORED,
    status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'approved', 'cancelled')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT DEFAULT 'system'
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_work_results_employee ON work_results(employee_id);
CREATE INDEX IF NOT EXISTS idx_work_results_period ON work_results(period_start, period_end);
CREATE INDEX IF NOT EXISTS idx_timesheets_employee_date ON timesheets(employee_id, work_date);
CREATE INDEX IF NOT EXISTS idx_production_employee ON production_results(employee_id);
