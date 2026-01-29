# 🚀 Інструкція з Міграції БД на Версію 2.0

## Огляд Змін

### Версія 1.0 → 2.0

| Категорія | Зміни |
|-----------|-------|
| **Нові таблиці** | position_groups, shift_schedules, position_schedules, split_reasons |
| **Нові поля** | parent_id в groups, group_id в rules, TIMESTAMP замість DATE |
| **Нові features** | Дерево груп, Immutability правил, Точність до хвилини, Розбиття періодів |
| **Нові views** | accrual_summary (materialized) |
| **Backward compatibility** | ⚠️ Частково - DATE → TIMESTAMP потребує уваги |

---

## ⚠️ ВАЖЛИВО: Backup Перед Міграцією!

### Створити Backup
```powershell
# PowerShell (Windows)
$backupFile = "C:\Work\zarplata\backups\backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').sql"
docker exec payroll_postgres pg_dump -U admin payroll > $backupFile

Write-Host "Backup створено: $backupFile" -ForegroundColor Green
```
```bash
# Bash (Linux/Mac)
backup_file="./backups/backup_$(date +%Y%m%d_%H%M%S).sql"
docker exec payroll_postgres pg_dump -U admin payroll > $backup_file

echo "Backup створено: $backup_file"
```

### Перевірити Backup
```powershell
# Перевірити що файл не порожній
Get-Item $backupFile | Select-Object Name, Length
```

---

## 📋 Варіант 1: Через Alembic (РЕКОМЕНДОВАНО)

### Переваги
- ✅ Версійність міграцій
- ✅ Можливість rollback
- ✅ Автоматичне виявлення змін
- ✅ Історія всіх міграцій

### Крок 1: Перевірити Поточну Версію
```powershell
cd C:\Work\zarplata\backend

docker-compose exec backend alembic current
```

**Очікуваний вивід:**
```
001_initial_schema (head)
```

### Крок 2: Виконати Міграцію
```powershell
docker-compose exec backend alembic upgrade head
```

**Що відбувається:**
1. Alembic читає файл `002_add_groups_hierarchy.py`
2. Виконує `upgrade()` функцію
3. Створює нові таблиці
4. Додає нові колонки
5. Конвертує DATE → TIMESTAMP
6. Створює індекси
7. Заповнює довідники
8. Створює materialized view

**Очікуваний вивід:**
```
INFO  [alembic.runtime.migration] Running upgrade 001 -> 002, add_groups_hierarchy_and_timestamps
Adding parent_id to groups...
Creating position_groups table...
Creating shift_schedules table...
Creating position_schedules table...
Updating calculation_rules...
Converting DATE to TIMESTAMP in calculation_rules...
Converting calculation_periods to TIMESTAMP...
Converting timesheets to TIMESTAMP...
Converting contracts to TIMESTAMP...
Adding audit fields to accrual_results...
Creating split_reasons table...
Creating accrual_summary materialized view...
Migration completed successfully! ✅
INFO  [alembic.runtime.migration] Upgrade completed
```

### Крок 3: Перевірити Версію
```powershell
docker-compose exec backend alembic current
```

**Очікуваний вивід:**
```
002_groups_hierarchy (head)
```

### Крок 4: Перевірити Структуру БД
```powershell
docker exec -it payroll_postgres psql -U admin -d payroll
```

**В psql:**
```sql
-- Список таблиць
\dt

-- Перевірити groups
\d groups
-- Має бути parent_id, level, full_path

-- Перевірити position_groups
\d position_groups
-- Нова таблиця має існувати

-- Перевірити calculation_rules
\d calculation_rules
-- Має бути group_id, valid_from (TIMESTAMP), replaces_rule_id

-- Перевірити calculation_periods
\d calculation_periods
-- start_datetime, end_datetime (TIMESTAMP)

-- Перевірити timesheets
\d timesheets
-- work_start, work_end (TIMESTAMP)

-- Перевірити materialized view
\d+ accrual_summary

-- Вийти
\q
```

---

## 📋 Варіант 2: Пряме Виконання SQL (для нової БД)

### ⚠️ Тільки для ПОВНОГО перестворення БД!

### Крок 1: Зупинити Систему
```powershell
cd C:\Work\zarplata
docker-compose down
```

### Крок 2: Видалити Volume БД
```powershell
docker volume rm zarplata_postgres_data
```

**Або:**
```powershell
docker-compose down -v  # видаляє всі volumes
```

### Крок 3: Запустити PostgreSQL
```powershell
docker-compose up -d postgres

# Почекати 5 секунд
Start-Sleep -Seconds 5
```

### Крок 4: Виконати SQL Схему
```powershell
# Копіювати SQL файл
docker cp docs/database/schema-full.sql payroll_postgres:/tmp/schema.sql

# Виконати
docker exec -it payroll_postgres psql -U admin -d payroll -f /tmp/schema.sql
```

**Очікуваний вивід:**
```
CREATE EXTENSION
CREATE TABLE
CREATE INDEX
...
CREATE MATERIALIZED VIEW
INSERT 0 14
```

### Крок 5: Перевірити
```powershell
docker exec -it payroll_postgres psql -U admin -d payroll -c "\dt"
```

### Крок 6: Запустити Всі Сервіси
```powershell
docker-compose up -d
```

---

## 📋 Варіант 3: Оновлення Існуючої БД (Складний)

### ⚠️ Рекомендується Alembic! Цей варіант тільки для розуміння.

### Послідовність Дій

#### 1. Backup (обов'язково!)
```powershell
docker exec payroll_postgres pg_dump -U admin payroll > backup_before_migration.sql
```

#### 2. Додати parent_id до groups
```sql
ALTER TABLE groups ADD COLUMN parent_id INTEGER;
ALTER TABLE groups ADD COLUMN level INTEGER NOT NULL DEFAULT 1;
ALTER TABLE groups ADD COLUMN full_path VARCHAR(500);

ALTER TABLE groups 
ADD CONSTRAINT fk_groups_parent 
FOREIGN KEY (parent_id) REFERENCES groups(id) ON DELETE SET NULL;

CREATE INDEX idx_groups_parent ON groups(parent_id);
CREATE INDEX idx_groups_level ON groups(level);
```

#### 3. Створити position_groups
```sql
CREATE TABLE position_groups (
    id SERIAL PRIMARY KEY,
    position_id INTEGER NOT NULL REFERENCES positions(id) ON DELETE CASCADE,
    group_id INTEGER NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    valid_from TIMESTAMP WITH TIME ZONE NOT NULL,
    valid_until TIMESTAMP WITH TIME ZONE,
    metadata JSONB,
    document_number VARCHAR(100),
    document_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL DEFAULT 'system',
    UNIQUE(position_id, group_id, valid_from)
);

CREATE INDEX idx_position_groups_position ON position_groups(position_id);
CREATE INDEX idx_position_groups_group ON position_groups(group_id);
CREATE INDEX idx_position_groups_dates ON position_groups(valid_from, valid_until);
```

#### 4. Конвертувати DATE → TIMESTAMP

**⚠️ НАЙСКЛАДНІША ЧАСТИНА!**
```sql
-- Приклад для calculation_rules
ALTER TABLE calculation_rules ADD COLUMN valid_from_ts TIMESTAMP WITH TIME ZONE;
ALTER TABLE calculation_rules ADD COLUMN valid_until_ts TIMESTAMP WITH TIME ZONE;

UPDATE calculation_rules 
SET valid_from_ts = valid_from::timestamp with time zone
WHERE valid_from IS NOT NULL;

UPDATE calculation_rules 
SET valid_until_ts = valid_until::timestamp with time zone
WHERE valid_until IS NOT NULL;

ALTER TABLE calculation_rules DROP COLUMN valid_from;
ALTER TABLE calculation_rules DROP COLUMN valid_until;

ALTER TABLE calculation_rules RENAME COLUMN valid_from_ts TO valid_from;
ALTER TABLE calculation_rules RENAME COLUMN valid_until_ts TO valid_until;

ALTER TABLE calculation_rules ALTER COLUMN valid_from SET NOT NULL;
```

**Повторити для:**
- `calculation_periods` (start_date/end_date → start_datetime/end_datetime)
- `timesheets` (work_date + hours → work_start/work_end)
- `contracts` (start_date/end_date → start_datetime/end_datetime)

#### 5. Решта змін

Дивись файл `002_add_groups_hierarchy.py` - там всі зміни детально!

---

## 🔍 Перевірка Після Міграції

### Автоматичний Скрипт Перевірки
```sql
-- Скопіюй в файл check_migration.sql
DO $$
DECLARE
    v_count INTEGER;
    v_error TEXT := '';
BEGIN
    -- Перевірка 1: Нові таблиці
    SELECT COUNT(*) INTO v_count
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name IN ('position_groups', 'shift_schedules', 'position_schedules', 'split_reasons');
    
    IF v_count != 4 THEN
        v_error := v_error || '❌ Не всі нові таблиці створені!' || E'\n';
    ELSE
        RAISE NOTICE '✅ Всі нові таблиці створені';
    END IF;
    
    -- Перевірка 2: parent_id в groups
    SELECT COUNT(*) INTO v_count
    FROM information_schema.columns
    WHERE table_name = 'groups' AND column_name = 'parent_id';
    
    IF v_count = 0 THEN
        v_error := v_error || '❌ groups.parent_id не існує!' || E'\n';
    ELSE
        RAISE NOTICE '✅ groups.parent_id існує';
    END IF;
    
    -- Перевірка 3: group_id в calculation_rules
    SELECT COUNT(*) INTO v_count
    FROM information_schema.columns
    WHERE table_name = 'calculation_rules' AND column_name = 'group_id';
    
    IF v_count = 0 THEN
        v_error := v_error || '❌ calculation_rules.group_id не існує!' || E'\n';
    ELSE
        RAISE NOTICE '✅ calculation_rules.group_id існує';
    END IF;
    
    -- Перевірка 4: TIMESTAMP в calculation_periods
    SELECT data_type INTO v_error
    FROM information_schema.columns
    WHERE table_name = 'calculation_periods' AND column_name = 'start_datetime';
    
    IF v_error NOT LIKE '%timestamp%' THEN
        RAISE EXCEPTION '❌ calculation_periods.start_datetime не TIMESTAMP!';
    ELSE
        RAISE NOTICE '✅ calculation_periods має TIMESTAMP';
    END IF;
    
    -- Перевірка 5: TIMESTAMP в timesheets
    SELECT data_type INTO v_error
    FROM information_schema.columns
    WHERE table_name = 'timesheets' AND column_name = 'work_start';
    
    IF v_error NOT LIKE '%timestamp%' THEN
        RAISE EXCEPTION '❌ timesheets.work_start не TIMESTAMP!';
    ELSE
        RAISE NOTICE '✅ timesheets має TIMESTAMP';
    END IF;
    
    -- Перевірка 6: Materialized View
    SELECT COUNT(*) INTO v_count
    FROM pg_matviews
    WHERE schemaname = 'public' AND matviewname = 'accrual_summary';
    
    IF v_count = 0 THEN
        v_error := v_error || '❌ accrual_summary view не існує!' || E'\n';
    ELSE
        RAISE NOTICE '✅ accrual_summary view існує';
    END IF;
    
    -- Перевірка 7: split_reasons заповнений
    SELECT COUNT(*) INTO v_count FROM split_reasons;
    
    IF v_count = 0 THEN
        v_error := v_error || '❌ split_reasons порожній!' || E'\n';
    ELSE
        RAISE NOTICE '✅ split_reasons містить % записів', v_count;
    END IF;
    
    -- Підсумок
    IF LENGTH(v_error) > 0 THEN
        RAISE EXCEPTION E'\n\n🔴 МІГРАЦІЯ НЕ ЗАВЕРШЕНА:\n%', v_error;
    ELSE
        RAISE NOTICE E'\n\n🟢 МІГРАЦІЯ УСПІШНА! ✅';
    END IF;
END $$;
```

**Виконати:**
```powershell
docker exec -it payroll_postgres psql -U admin -d payroll -f /path/to/check_migration.sql
```

---

## 🔄 Rollback (Відкат)

### Через Alembic
```powershell
# Відкат на одну версію назад
docker-compose exec backend alembic downgrade -1

# Відкат на конкретну версію
docker-compose exec backend alembic downgrade 001_initial_schema
```

### З Backup
```powershell
# Зупинити систему
docker-compose down

# Видалити поточну БД
docker volume rm zarplata_postgres_data

# Запустити PostgreSQL
docker-compose up -d postgres
Start-Sleep -Seconds 5

# Відновити з backup
Get-Content backup_before_migration.sql | docker exec -i payroll_postgres psql -U admin payroll

# Запустити всі сервіси
docker-compose up -d
```

---

## 📊 Тестові Дані (Seed Data)

### Після успішної міграції можна додати тестові дані:

#### 1. Дерево Груп
```powershell
docker cp seed-data/01-groups-hierarchy.sql payroll_postgres:/tmp/
docker exec -it payroll_postgres psql -U admin -d payroll -f /tmp/01-groups-hierarchy.sql
```

#### 2. Прив'язка Позицій до Груп
```powershell
docker cp seed-data/02-position-groups.sql payroll_postgres:/tmp/
docker exec -it payroll_postgres psql -U admin -d payroll -f /tmp/02-position-groups.sql
```

#### 3. Правила для Груп
```powershell
docker cp seed-data/03-rules-for-groups.sql payroll_postgres:/tmp/
docker exec -it payroll_postgres psql -U admin -d payroll -f /tmp/03-rules-for-groups.sql
```

#### 4. Складний Табель
```powershell
docker cp seed-data/04-complex-timesheet.sql payroll_postgres:/tmp/
docker exec -it payroll_postgres psql -U admin -d payroll -f /tmp/04-complex-timesheet.sql
```

---

## 🧪 Тестування Після Міграції

### 1. Перевірити Ієрархію Груп
```sql
-- Має показати дерево груп
WITH RECURSIVE tree AS (
    SELECT id, code, name, parent_id, level, 
           name as path
    FROM groups
    WHERE parent_id IS NULL
    
    UNION ALL
    
    SELECT g.id, g.code, g.name, g.parent_id, g.level,
           t.path || ' → ' || g.name
    FROM groups g
    JOIN tree t ON g.parent_id = t.id
)
SELECT 
    REPEAT('  ', level - 1) || name as hierarchy,
    code,
    level
FROM tree
ORDER BY path;
```

### 2. Перевірити TIMESTAMP
```sql
-- Має показати TIMESTAMP з timezone
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name IN ('calculation_periods', 'timesheets', 'contracts', 'calculation_rules')
  AND column_name LIKE '%date%'
ORDER BY table_name, column_name;
```

### 3. Перевірити Materialized View
```sql
-- Має повернути дані (якщо є нарахування)
SELECT COUNT(*) as total_records FROM accrual_summary;

-- Перевірити структуру
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'accrual_summary'
ORDER BY ordinal_position;
```

### 4. Тестовий Розрахунок
```sql
-- Створити тестовий період з TIMESTAMP
INSERT INTO calculation_periods (
    period_code,
    period_name,
    start_datetime,
    end_datetime,
    period_type,
    status,
    created_by
) VALUES (
    'TEST-2024-01',
    'Тестовий період',
    '2024-01-01 00:00:00+00'::timestamp with time zone,
    '2024-01-31 23:59:59+00'::timestamp with time zone,
    'monthly',
    'draft',
    'migration_test'
);

-- Перевірити що створилось
SELECT * FROM calculation_periods WHERE period_code = 'TEST-2024-01';
```

---

## 🚨 Troubleshooting (Вирішення Проблем)

### Проблема 1: Alembic не виконується

**Помилка:**
```
Can't locate revision identified by '001_initial_schema'
```

**Рішення:**
```powershell
# Перевірити історію
docker-compose exec backend alembic history

# Примусово встановити поточну версію
docker-compose exec backend alembic stamp head
```

---

### Проблема 2: Помилка конвертації DATE → TIMESTAMP

**Помилка:**
```
ERROR: column "start_date" does not exist
```

**Причина:** Колонка вже була конвертована або має іншу назву.

**Рішення:**
```sql
-- Перевірити які колонки існують
\d calculation_periods

-- Якщо start_datetime вже є - пропустити цей крок
```

---

### Проблема 3: Конфлікт даних при створенні UNIQUE constraint

**Помилка:**
```
ERROR: could not create unique index "uq_position_group_date"
DETAIL: Key (position_id, group_id, valid_from)=(123, 5, 2024-01-01) is duplicated
```

**Рішення:**
```sql
-- Знайти дублікати
SELECT position_id, group_id, valid_from, COUNT(*)
FROM position_groups
GROUP BY position_id, group_id, valid_from
HAVING COUNT(*) > 1;

-- Видалити дублікати (залишити найновіший)
DELETE FROM position_groups
WHERE id NOT IN (
    SELECT MAX(id)
    FROM position_groups
    GROUP BY position_id, group_id, valid_from
);
```

---

### Проблема 4: Materialized View не створюється

**Помилка:**
```
ERROR: relation "accrual_summary" already exists
```

**Рішення:**
```sql
-- Видалити старий view
DROP MATERIALIZED VIEW IF EXISTS accrual_summary CASCADE;

-- Створити заново (виконати SQL з міграції)
```

---

### Проблема 5: Недостатньо прав

**Помилка:**
```
ERROR: permission denied for table groups
```

**Рішення:**
```sql
-- Надати права
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO admin;
```

---

## 📝 Checklist Міграції

### Перед Міграцією

- [ ] Створив backup БД
- [ ] Перевірив що backup не порожній
- [ ] Зупинив frontend/backend (залишив тільки postgres)
- [ ] Перевірив поточну версію Alembic
- [ ] Прочитав цю інструкцію повністю

### Під Час Міграції

- [ ] Виконав `alembic upgrade head`
- [ ] Дочекався завершення (не перервав!)
- [ ] Перевірив що немає помилок у виводі

### Після Міграції

- [ ] Перевірив версію Alembic (`alembic current`)
- [ ] Перевірив структуру таблиць (`\dt`, `\d groups`)
- [ ] Виконав скрипт перевірки
- [ ] Перевірив що materialized view існує
- [ ] Додав тестові дані (опціонально)
- [ ] Запустив повну систему (`docker-compose up -d`)
- [ ] Перевірив що frontend/backend працюють
- [ ] Оновив документацію (якщо потрібно)

---

## 🎓 Наступні Кроки

Після успішної міграції:

1. **Оновити Backend Models** - `app/models/*.py`
2. **Додати API для груп** - `app/api/endpoints/groups.py`
3. **Додати логіку пошуку правил** - `app/services/rule_finder.py`
4. **Додати логіку розбиття періодів** - `app/services/period_splitter.py`
5. **Оновити Frontend** - відобразити групи, розбиття періодів

---

## 📞 Підтримка

При проблемах:

1. Перевір логи: `docker-compose logs backend`
2. Перевір БД: `docker logs payroll_postgres`
3. Подивись у файл міграції: `alembic/versions/002_*.py`
4. Відкоть з backup якщо щось пішло не так

---

## ✅ Успішної Міграції!

**Версія документа:** 1.0  
**Дата:** 2025-01-30  
**Автор:** Система розрахунку зарплат

---

**ВАЖЛИВО:** Після міграції обов'язково протестуй всі функції системи!