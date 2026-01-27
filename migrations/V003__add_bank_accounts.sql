-- ============================================================================
-- Міграція V003: Банківські рахунки працівників
-- Дата: 2024-01-27
-- Опис: Підтримка кількох банківських рахунків для виплат
-- ============================================================================

-- UP: Застосування міграції
-- ----------------------------------------------------------------------------

-- Банки
CREATE TABLE banks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    mfo TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    short_name TEXT,
    is_active INTEGER DEFAULT 1
);

-- Базові банки України
INSERT INTO banks (mfo, name, short_name) VALUES
('320649', 'АТ КБ "ПриватБанк"', 'ПриватБанк'),
('305299', 'АТ "Ощадбанк"', 'Ощадбанк'),
('322001', 'АТ "УКРСИББАНК"', 'УКРСИББАНК'),
('300346', 'АТ "Райффайзен Банк"', 'Райффайзен'),
('325321', 'АТ "ПУМБ"', 'ПУМБ'),
('380805', 'АТ "monobank"', 'monobank');

-- Банківські рахунки працівників
CREATE TABLE employee_bank_accounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    bank_id INTEGER REFERENCES banks(id),
    account_number TEXT NOT NULL,
    iban TEXT,
    card_number TEXT,
    account_type TEXT DEFAULT 'salary' CHECK(account_type IN ('salary', 'bonus', 'other')),
    is_primary INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1,
    valid_from TEXT DEFAULT (date('now')),
    valid_until TEXT,
    notes TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_bank_accounts_employee ON employee_bank_accounts(employee_id);
CREATE INDEX idx_bank_accounts_primary ON employee_bank_accounts(employee_id, is_primary);

-- Оновлюємо таблицю виплат для зв'язку з рахунком
ALTER TABLE doc_payment_lines ADD COLUMN bank_account_id INTEGER REFERENCES employee_bank_accounts(id);

-- View для отримання основного рахунку працівника
CREATE VIEW v_employee_primary_bank_account AS
SELECT
    e.id as employee_id,
    e.personnel_number,
    e.last_name || ' ' || e.first_name as employee_name,
    ba.id as account_id,
    ba.iban,
    ba.card_number,
    b.name as bank_name,
    b.mfo
FROM employees e
LEFT JOIN employee_bank_accounts ba ON ba.employee_id = e.id AND ba.is_primary = 1 AND ba.is_active = 1
LEFT JOIN banks b ON b.id = ba.bank_id
WHERE e.is_active = 1;

-- ============================================================================
-- ROLLBACK
-- ============================================================================
-- DROP VIEW IF EXISTS v_employee_primary_bank_account;
-- DROP TABLE IF EXISTS employee_bank_accounts;
-- DROP TABLE IF EXISTS banks;
