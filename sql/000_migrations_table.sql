-- ============================================================================
-- СИСТЕМА МІГРАЦІЙ
-- Ця таблиця відстежує які міграції вже застосовані
-- ============================================================================

CREATE TABLE IF NOT EXISTS _migrations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    version TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    applied_at TEXT DEFAULT (datetime('now')),
    checksum TEXT,
    execution_time_ms INTEGER,
    status TEXT DEFAULT 'applied' CHECK(status IN ('applied', 'failed', 'rolled_back'))
);

CREATE INDEX IF NOT EXISTS idx_migrations_version ON _migrations(version);
CREATE INDEX IF NOT EXISTS idx_migrations_status ON _migrations(status);

-- Записуємо початкову міграцію (schema)
INSERT OR IGNORE INTO _migrations (version, name, checksum)
VALUES ('000', 'initial_schema', 'initial');
