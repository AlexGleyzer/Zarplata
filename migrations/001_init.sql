-- Migration 001: Initial Schema
-- Creates base tables and schema metadata

-- Schema metadata table
CREATE TABLE IF NOT EXISTS schema_meta (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    version TEXT NOT NULL,
    description TEXT,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert initial version
INSERT INTO schema_meta (version, description) VALUES ('1.0.0', 'Initial schema');

-- Base values table (minimum wage, living wage, etc.)
CREATE TABLE IF NOT EXISTS base_values (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    value REAL NOT NULL,
    effective_from DATE NOT NULL,
    effective_to DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT DEFAULT 'system'
);

-- Accrual types table
CREATE TABLE IF NOT EXISTS accrual_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('accrual', 'deduction')),
    description TEXT,
    is_active INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
