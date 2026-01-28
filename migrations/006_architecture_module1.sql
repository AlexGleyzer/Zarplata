-- Migration 006: Module 1 - Structure and Employees
-- Calculation rules and templates

-- Calculation rules with SQL code
CREATE TABLE IF NOT EXISTS calculation_rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    rule_type TEXT NOT NULL CHECK (rule_type IN ('accrual', 'deduction', 'tax')),
    sql_formula TEXT NOT NULL,
    parameters TEXT, -- JSON with rule parameters
    is_active INTEGER DEFAULT 1,
    version INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT DEFAULT 'system',
    updated_by TEXT DEFAULT 'system'
);

-- Rule versions for audit
CREATE TABLE IF NOT EXISTS rule_versions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    rule_id INTEGER NOT NULL REFERENCES calculation_rules(id),
    version INTEGER NOT NULL,
    sql_formula TEXT NOT NULL,
    parameters TEXT,
    effective_from DATE NOT NULL,
    effective_to DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT DEFAULT 'system'
);

-- Calculation templates
CREATE TABLE IF NOT EXISTS calculation_templates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    is_active INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT DEFAULT 'system',
    updated_by TEXT DEFAULT 'system'
);

-- Template rules (link between templates and rules)
CREATE TABLE IF NOT EXISTS template_rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    template_id INTEGER NOT NULL REFERENCES calculation_templates(id),
    rule_id INTEGER NOT NULL REFERENCES calculation_rules(id),
    execution_order INTEGER NOT NULL,
    is_required INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(template_id, rule_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_template_rules_template ON template_rules(template_id);
CREATE INDEX IF NOT EXISTS idx_template_rules_order ON template_rules(template_id, execution_order);
