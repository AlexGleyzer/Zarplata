-- Migration 008: Module 3 - Periods and Accruals
-- Calculation periods, accrual documents and results

-- Calculation periods
CREATE TABLE IF NOT EXISTS calculation_periods (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    period_code TEXT NOT NULL UNIQUE,
    period_name TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    period_type TEXT NOT NULL CHECK (period_type IN ('monthly', 'bi-weekly', 'weekly')),
    status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'open', 'closed', 'archived')),
    working_days INTEGER,
    working_hours REAL,
    closed_at TIMESTAMP,
    closed_by TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT DEFAULT 'system',
    updated_by TEXT DEFAULT 'system'
);

-- Accrual documents
CREATE TABLE IF NOT EXISTS accrual_documents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_number TEXT NOT NULL UNIQUE,
    period_id INTEGER NOT NULL REFERENCES calculation_periods(id),
    template_id INTEGER NOT NULL REFERENCES calculation_templates(id),
    description TEXT,
    status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'in_review', 'approved', 'cancelled')),
    total_accrued REAL DEFAULT 0,
    total_deducted REAL DEFAULT 0,
    total_net REAL DEFAULT 0,
    approved_date TIMESTAMP,
    approved_by TEXT,
    cancelled_date TIMESTAMP,
    cancelled_by TEXT,
    cancellation_reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT DEFAULT 'system',
    updated_by TEXT DEFAULT 'system'
);

-- Accrual results (IMMUTABLE!)
CREATE TABLE IF NOT EXISTS accrual_results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id INTEGER NOT NULL REFERENCES accrual_documents(id),
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    rule_id INTEGER NOT NULL REFERENCES calculation_rules(id),
    accrual_type TEXT NOT NULL CHECK (accrual_type IN ('accrual', 'deduction')),
    amount REAL NOT NULL,
    base_amount REAL, -- amount used for calculation
    rate REAL, -- rate used (percent, hourly rate, etc.)
    calculation_details TEXT, -- JSON with calculation breakdown
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'cancelled')),
    cancelled_by_result_id INTEGER REFERENCES accrual_results(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT DEFAULT 'system'
);

-- Accrual operations (individual operations log)
CREATE TABLE IF NOT EXISTS accrual_operations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    result_id INTEGER NOT NULL REFERENCES accrual_results(id),
    operation_type TEXT NOT NULL,
    description TEXT,
    amount REAL NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Accrual parts (sub-period breakdown)
CREATE TABLE IF NOT EXISTS accrual_parts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    result_id INTEGER NOT NULL REFERENCES accrual_results(id),
    part_start DATE NOT NULL,
    part_end DATE NOT NULL,
    days INTEGER,
    hours REAL,
    amount REAL NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Change requests for documents
CREATE TABLE IF NOT EXISTS change_requests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id INTEGER NOT NULL REFERENCES accrual_documents(id),
    request_type TEXT NOT NULL CHECK (request_type IN ('correction', 'cancellation', 'recalculation')),
    reason TEXT NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    requested_by TEXT NOT NULL,
    requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reviewed_by TEXT,
    reviewed_at TIMESTAMP,
    review_notes TEXT,
    new_document_id INTEGER REFERENCES accrual_documents(id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_accrual_docs_period ON accrual_documents(period_id);
CREATE INDEX IF NOT EXISTS idx_accrual_docs_status ON accrual_documents(status);
CREATE INDEX IF NOT EXISTS idx_accrual_results_doc ON accrual_results(document_id);
CREATE INDEX IF NOT EXISTS idx_accrual_results_employee ON accrual_results(employee_id);
CREATE INDEX IF NOT EXISTS idx_accrual_results_status ON accrual_results(status);
