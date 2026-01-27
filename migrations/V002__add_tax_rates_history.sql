-- ============================================================================
-- Міграція V002: Історія ставок податків
-- Дата: 2024-01-27
-- Опис: Дозволяє зберігати історію змін податкових ставок для коректного
--       розрахунку при змінах законодавства всередині періоду
-- ============================================================================

-- UP: Застосування міграції
-- ----------------------------------------------------------------------------

-- Таблиця ставок податків з історією
CREATE TABLE tax_rates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tax_code TEXT NOT NULL,
    tax_name TEXT NOT NULL,
    rate REAL NOT NULL,
    rate_type TEXT NOT NULL CHECK(rate_type IN ('percent', 'fixed')),
    min_base REAL,
    max_base REAL,
    valid_from TEXT NOT NULL,
    valid_until TEXT,
    legal_reference TEXT,
    notes TEXT,
    created_by INTEGER REFERENCES users(id),
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_tax_rates_code ON tax_rates(tax_code);
CREATE INDEX idx_tax_rates_dates ON tax_rates(valid_from, valid_until);

-- Базові ставки ПДФО та військового збору
INSERT INTO tax_rates (tax_code, tax_name, rate, rate_type, valid_from, legal_reference) VALUES
('pdfo', 'ПДФО', 18.0, 'percent', '2016-01-01', 'ПКУ ст.167'),
('military', 'Військовий збір', 1.5, 'percent', '2014-08-03', 'ПКУ п.161'),
('esv', 'ЄСВ (роботодавець)', 22.0, 'percent', '2016-01-01', 'Закон про ЄСВ');

-- View для отримання актуальних ставок на дату
CREATE VIEW v_current_tax_rates AS
SELECT
    tr.*
FROM tax_rates tr
WHERE tr.valid_from <= date('now')
  AND (tr.valid_until IS NULL OR tr.valid_until >= date('now'));

-- Функція отримання ставки на конкретну дату (через тригер/view)
CREATE VIEW v_tax_rate_on_date AS
SELECT
    tax_code,
    tax_name,
    rate,
    rate_type,
    valid_from,
    valid_until
FROM tax_rates;

-- ============================================================================
-- ROLLBACK
-- ============================================================================
-- DROP VIEW IF EXISTS v_current_tax_rates;
-- DROP VIEW IF EXISTS v_tax_rate_on_date;
-- DROP TABLE IF EXISTS tax_rates;
