# Система міграцій бази даних

## Огляд

Система міграцій дозволяє:
- Версіонувати зміни в структурі БД
- Відстежувати які міграції застосовані
- Безпечно оновлювати БД на production

## Команди

```bash
# Застосувати всі нові міграції
npm run db:migrate

# Показати статус міграцій
npm run db:migrate:status

# Створити нову міграцію
npm run db:migrate:create add_new_feature

# Створити бекап перед міграцією
npm run db:backup
```

## Структура проєкту

```
Zarplata/
├── migrations/                    # Файли міграцій
│   ├── V001__add_employee_bonus_settings.sql
│   ├── V002__add_tax_rates_history.sql
│   └── V003__add_bank_accounts.sql
├── sql/
│   ├── 000_migrations_table.sql  # Таблиця _migrations
│   ├── 001_schema.sql            # Початкова схема
│   └── 002_seed_data.sql         # Тестові дані
└── src/db/
    └── migrate.js                # Runner міграцій
```

## Формат файлів міграцій

Файли повинні мати формат: `V{номер}__{опис}.sql`

Приклад: `V001__add_employee_bonus_settings.sql`

```sql
-- ============================================================================
-- Міграція V001: Додати налаштування бонусів
-- Дата: 2024-01-27
-- ============================================================================

-- UP: Застосування міграції
-- ----------------------------------------------------------------------------

CREATE TABLE employee_bonus_settings (
    ...
);

ALTER TABLE existing_table ADD COLUMN new_column TEXT;

-- ============================================================================
-- ROLLBACK (для ручного відкату)
-- ============================================================================
-- DROP TABLE IF EXISTS employee_bonus_settings;
```

## Таблиця _migrations

```sql
CREATE TABLE _migrations (
    id INTEGER PRIMARY KEY,
    version TEXT UNIQUE NOT NULL,     -- '001', '002', ...
    name TEXT NOT NULL,               -- 'add_employee_bonus_settings'
    applied_at TEXT,                  -- Дата застосування
    checksum TEXT,                    -- MD5 файлу
    execution_time_ms INTEGER,        -- Час виконання
    status TEXT                       -- 'applied', 'failed', 'rolled_back'
);
```

## Правила написання міграцій

### 1. Завжди робіть бекап

```bash
npm run db:backup
# Створить: data/backups/payroll_20240127_143052.db
```

### 2. Один файл - одна логічна зміна

```
✅ V001__add_employee_bonus_settings.sql
✅ V002__add_tax_rates_history.sql

❌ V001__add_everything_at_once.sql
```

### 3. Міграції повинні бути ідемпотентними (де можливо)

```sql
-- Використовуйте IF NOT EXISTS
CREATE TABLE IF NOT EXISTS new_table (...);
CREATE INDEX IF NOT EXISTS idx_name ON table(column);

-- Для INSERT використовуйте OR IGNORE
INSERT OR IGNORE INTO reference_table VALUES (...);
```

### 4. SQLite обмеження

SQLite **не підтримує**:
- `DROP COLUMN` (до версії 3.35)
- `ALTER COLUMN`
- Зміну типу колонки

**Обхідний шлях** для видалення колонки:
```sql
-- 1. Створити нову таблицю без колонки
CREATE TABLE new_table AS
SELECT col1, col2 -- без col3
FROM old_table;

-- 2. Видалити стару таблицю
DROP TABLE old_table;

-- 3. Перейменувати
ALTER TABLE new_table RENAME TO old_table;
```

### 5. Завжди додавайте ROLLBACK коментар

```sql
-- ============================================================================
-- ROLLBACK
-- ============================================================================
-- DROP TABLE IF EXISTS new_table;
-- Примітка для ALTER TABLE: потрібно перестворити таблицю
```

## Приклади міграцій

### Додавання нової таблиці

```sql
CREATE TABLE employee_documents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    document_type TEXT NOT NULL,
    file_path TEXT NOT NULL,
    uploaded_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_emp_docs ON employee_documents(employee_id);
```

### Додавання колонки

```sql
ALTER TABLE employees ADD COLUMN middle_name_latin TEXT;
ALTER TABLE employees ADD COLUMN passport_expires TEXT;
```

### Додавання довідникових даних

```sql
INSERT OR IGNORE INTO accrual_types (code, name, category)
VALUES
    ('maternity_pay', 'Декретні виплати', 'social'),
    ('child_care', 'Допомога на дитину', 'social');
```

### Створення VIEW

```sql
CREATE VIEW IF NOT EXISTS v_employee_full_info AS
SELECT
    e.*,
    d.name as department_name,
    p.name as position_name,
    ea.base_salary
FROM employees e
LEFT JOIN employee_assignments ea ON ea.employee_id = e.id AND ea.is_active = 1
LEFT JOIN departments d ON d.id = ea.department_id
LEFT JOIN positions p ON p.id = ea.position_id
WHERE e.is_active = 1;
```

## Робочий процес

### Розробка

1. Створіть міграцію:
   ```bash
   npm run db:migrate:create add_new_feature
   ```

2. Відредагуйте файл `migrations/V00X__add_new_feature.sql`

3. Застосуйте локально:
   ```bash
   npm run db:migrate
   ```

4. Перевірте статус:
   ```bash
   npm run db:migrate:status
   ```

### Production

1. **Обов'язково** створіть бекап:
   ```bash
   npm run db:backup
   ```

2. Застосуйте міграції:
   ```bash
   npm run db:migrate
   ```

3. У разі проблем - відновіть з бекапу:
   ```bash
   cp data/backups/payroll_YYYYMMDD_HHMMSS.db data/payroll.db
   ```

## Порядок виконання при розгортанні

```bash
# 1. Зупинити додаток (якщо потрібно)

# 2. Бекап
npm run db:backup

# 3. Міграції
npm run db:migrate

# 4. Перевірка
npm run db:migrate:status

# 5. Запуск додатку
npm run dev
```

## Troubleshooting

### Міграція не застосовується

Перевірте:
1. Чи правильний формат імені файлу: `V{число}__{опис}.sql`
2. Чи файл в папці `migrations/`
3. `npm run db:migrate:status` - можливо вже застосована

### Помилка синтаксису SQL

Міграція позначається як `failed`. Виправте SQL та запустіть знову.

### Потрібно відкотити

1. Створіть бекап поточного стану
2. Відновіть з попереднього бекапу
3. Або створіть нову міграцію з протилежними змінами
