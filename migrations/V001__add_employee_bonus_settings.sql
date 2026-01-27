-- ============================================================================
-- Міграція V001: Додати налаштування бонусів для працівників
-- Дата: 2024-01-27
-- ============================================================================

-- UP: Застосування міграції
-- ----------------------------------------------------------------------------

-- Таблиця індивідуальних налаштувань бонусів
CREATE TABLE employee_bonus_settings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    assignment_id INTEGER REFERENCES employee_assignments(id),
    bonus_type TEXT NOT NULL CHECK(bonus_type IN ('monthly', 'quarterly', 'yearly', 'project')),
    calculation_method TEXT NOT NULL CHECK(calculation_method IN ('percent', 'fixed', 'formula')),
    base_value REAL NOT NULL,
    max_value REAL,
    conditions TEXT,
    valid_from TEXT NOT NULL,
    valid_until TEXT,
    approved_by INTEGER REFERENCES users(id),
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_bonus_settings_employee ON employee_bonus_settings(employee_id);
CREATE INDEX idx_bonus_settings_active ON employee_bonus_settings(is_active);

-- Додаємо поле для збереження формули бонусу в правилах
ALTER TABLE accrual_rule_templates ADD COLUMN bonus_formula TEXT;

-- Додаємо поле для максимальної суми бонусу
ALTER TABLE accrual_rule_templates ADD COLUMN max_amount REAL;

-- ============================================================================
-- ROLLBACK (для ручного відкату)
-- ============================================================================
-- DROP TABLE IF EXISTS employee_bonus_settings;
-- Примітка: SQLite не підтримує DROP COLUMN, тому для відкату ALTER TABLE
-- потрібно створити нову таблицю без цих полів і перенести дані
