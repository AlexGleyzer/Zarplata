-- Migration 009: Module 4 - Payments
-- Payment rules, documents and bank statements

-- Payment rules
CREATE TABLE IF NOT EXISTS payment_rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    payment_type TEXT NOT NULL CHECK (payment_type IN ('salary', 'advance', 'bonus', 'vacation', 'sick_leave')),
    calculation_method TEXT NOT NULL, -- formula or fixed
    is_active INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT DEFAULT 'system'
);

-- Payment documents
CREATE TABLE IF NOT EXISTS payment_documents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_number TEXT NOT NULL UNIQUE,
    period_id INTEGER NOT NULL REFERENCES calculation_periods(id),
    payment_date DATE NOT NULL,
    payment_type TEXT NOT NULL CHECK (payment_type IN ('salary', 'advance', 'bonus', 'vacation', 'sick_leave')),
    description TEXT,
    total_amount REAL DEFAULT 0,
    status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'approved', 'paid', 'cancelled')),
    approved_date TIMESTAMP,
    approved_by TEXT,
    paid_date TIMESTAMP,
    paid_by TEXT,
    cancelled_date TIMESTAMP,
    cancelled_by TEXT,
    cancellation_reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT DEFAULT 'system',
    updated_by TEXT DEFAULT 'system'
);

-- Payment items (individual payments to employees)
CREATE TABLE IF NOT EXISTS payment_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id INTEGER NOT NULL REFERENCES payment_documents(id),
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    amount REAL NOT NULL,
    payment_method TEXT DEFAULT 'bank_transfer' CHECK (payment_method IN ('bank_transfer', 'cash', 'card')),
    bank_account TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'failed', 'cancelled')),
    paid_at TIMESTAMP,
    failure_reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Payment operations (actual payment facts)
CREATE TABLE IF NOT EXISTS payment_operations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    payment_item_id INTEGER NOT NULL REFERENCES payment_items(id),
    operation_type TEXT NOT NULL CHECK (operation_type IN ('payment', 'reversal', 'adjustment')),
    amount REAL NOT NULL,
    reference_number TEXT,
    bank_reference TEXT,
    operation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT DEFAULT 'system'
);

-- Payment-Accrual links (which accruals are paid by which payment)
CREATE TABLE IF NOT EXISTS payment_accrual_links (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    payment_item_id INTEGER NOT NULL REFERENCES payment_items(id),
    accrual_result_id INTEGER NOT NULL REFERENCES accrual_results(id),
    amount REAL NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(payment_item_id, accrual_result_id)
);

-- Bank statements
CREATE TABLE IF NOT EXISTS bank_statements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    statement_date DATE NOT NULL,
    bank_name TEXT NOT NULL,
    account_number TEXT NOT NULL,
    opening_balance REAL NOT NULL,
    closing_balance REAL NOT NULL,
    total_credits REAL DEFAULT 0,
    total_debits REAL DEFAULT 0,
    statement_file TEXT, -- path to uploaded file
    status TEXT DEFAULT 'uploaded' CHECK (status IN ('uploaded', 'processed', 'reconciled')),
    processed_at TIMESTAMP,
    processed_by TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT DEFAULT 'system'
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_payment_docs_period ON payment_documents(period_id);
CREATE INDEX IF NOT EXISTS idx_payment_docs_status ON payment_documents(status);
CREATE INDEX IF NOT EXISTS idx_payment_items_doc ON payment_items(document_id);
CREATE INDEX IF NOT EXISTS idx_payment_items_employee ON payment_items(employee_id);
CREATE INDEX IF NOT EXISTS idx_payment_accrual_links_payment ON payment_accrual_links(payment_item_id);
CREATE INDEX IF NOT EXISTS idx_payment_accrual_links_accrual ON payment_accrual_links(accrual_result_id);
