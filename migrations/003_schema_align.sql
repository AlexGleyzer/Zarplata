-- Migration 003: Schema Alignment
-- Contracts and employee bases

-- Contracts table
CREATE TABLE IF NOT EXISTS contracts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    contract_number TEXT NOT NULL UNIQUE,
    contract_type TEXT NOT NULL CHECK (contract_type IN ('salary', 'hourly', 'contract')),
    start_date DATE NOT NULL,
    end_date DATE,
    base_amount REAL NOT NULL,
    currency TEXT DEFAULT 'UAH',
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'terminated')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT DEFAULT 'system',
    updated_by TEXT DEFAULT 'system'
);

-- Employee bases (personal rates, salaries)
CREATE TABLE IF NOT EXISTS employee_bases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    base_type TEXT NOT NULL,
    value REAL NOT NULL,
    effective_from DATE NOT NULL,
    effective_to DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT DEFAULT 'system'
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_contracts_employee ON contracts(employee_id);
CREATE INDEX IF NOT EXISTS idx_employee_bases_employee ON employee_bases(employee_id);
CREATE INDEX IF NOT EXISTS idx_employee_org_history_employee ON employee_org_unit_history(employee_id);
