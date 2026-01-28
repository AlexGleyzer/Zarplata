-- Migration 002: Domain Core Tables
-- Basic domain tables for payroll system

-- Organizational units (org_units)
CREATE TABLE IF NOT EXISTS org_units (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    unit_type TEXT NOT NULL CHECK (unit_type IN ('company', 'department', 'team')),
    parent_id INTEGER REFERENCES org_units(id),
    is_active INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT DEFAULT 'system',
    updated_by TEXT DEFAULT 'system'
);

-- Employees table
CREATE TABLE IF NOT EXISTS employees (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_code TEXT NOT NULL UNIQUE,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    hire_date DATE NOT NULL,
    termination_date DATE,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'terminated', 'on_leave')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT DEFAULT 'system',
    updated_by TEXT DEFAULT 'system'
);

-- Employee org unit history
CREATE TABLE IF NOT EXISTS employee_org_unit_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    org_unit_id INTEGER NOT NULL REFERENCES org_units(id),
    position TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    is_primary INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT DEFAULT 'system'
);

-- Employee categories history
CREATE TABLE IF NOT EXISTS employee_categories_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    category TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT DEFAULT 'system'
);
