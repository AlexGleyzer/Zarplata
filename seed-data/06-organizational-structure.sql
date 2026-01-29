-- ============================================================
-- СТРУКТУРА ПІДПРИЄМСТВА: Повна ієрархія підрозділів
-- ============================================================

-- Очистити (ОБЕРЕЖНО!)
TRUNCATE organizational_units RESTART IDENTITY CASCADE;

-- ============================================================
-- РІВЕНЬ 1: КОМПАНІЯ (ROOT)
-- ============================================================

INSERT INTO organizational_units (id, parent_id, code, name, level, full_path, unit_type, is_active, created_by) VALUES
(1, NULL, 'COMP', 'ТОВ "Футура"', 1, 'ТОВ "Футура"', 'company', true, 'seed_data');

-- ============================================================
-- РІВЕНЬ 2: ГОЛОВНІ ДЕПАРТАМЕНТИ
-- ============================================================

INSERT INTO organizational_units (id, parent_id, code, name, level, unit_type, is_active, created_by) VALUES
-- Продажі
(10, 1, 'SALES', 'Департамент продажів', 2, 'department', true, 'seed_data'),
-- Операції
(20, 1, 'OPS', 'Департамент операцій', 2, 'department', true, 'seed_data'),
-- IT
(30, 1, 'IT', 'IT Департамент', 2, 'department', true, 'seed_data'),
-- Фінанси
(40, 1, 'FIN', 'Фінансовий департамент', 2, 'department', true, 'seed_data'),
-- HR
(50, 1, 'HR', 'HR Департамент', 2, 'department', true, 'seed_data'),
-- Маркетинг
(60, 1, 'MKT', 'Департамент маркетингу', 2, 'department', true, 'seed_data');

-- ============================================================
-- РІВЕНЬ 3: ВІДДІЛИ ПРОДАЖІВ
-- ============================================================

INSERT INTO organizational_units (id, parent_id, code, name, level, unit_type, cost_center, is_active, created_by) VALUES
(11, 10, 'SALES-EAST', 'Відділ продажів Схід', 3, 'division', 'CC-SALES-001', true, 'seed_data'),
(12, 10, 'SALES-WEST', 'Відділ продажів Захід', 3, 'division', 'CC-SALES-002', true, 'seed_data'),
(13, 10, 'SALES-NORTH', 'Відділ продажів Північ', 3, 'division', 'CC-SALES-003', true, 'seed_data'),
(14, 10, 'SALES-SOUTH', 'Відділ продажів Південь', 3, 'division', 'CC-SALES-004', true, 'seed_data');

-- ============================================================
-- РІВЕНЬ 3: ВІДДІЛИ ОПЕРАЦІЙ
-- ============================================================

INSERT INTO organizational_units (id, parent_id, code, name, level, unit_type, is_active, created_by) VALUES
(21, 20, 'OPS-LOG', 'Відділ логістики', 3, 'division', true, 'seed_data'),
(22, 20, 'OPS-PROD', 'Відділ виробництва', 3, 'division', true, 'seed_data'),
(23, 20, 'OPS-QA', 'Відділ контролю якості', 3, 'division', true, 'seed_data');

-- ============================================================
-- РІВЕНЬ 3: IT ВІДДІЛИ
-- ============================================================

INSERT INTO organizational_units (id, parent_id, code, name, level, unit_type, is_active, created_by) VALUES
(31, 30, 'IT-DEV', 'Відділ розробки', 3, 'division', true, 'seed_data'),
(32, 30, 'IT-INFRA', 'Відділ інфраструктури', 3, 'division', true, 'seed_data'),
(33, 30, 'IT-SUPPORT', 'Відділ технічної підтримки', 3, 'division', true, 'seed_data'),
(34, 30, 'IT-SEC', 'Відділ інформаційної безпеки', 3, 'division', true, 'seed_data');

-- ============================================================
-- РІВЕНЬ 3: ФІНАНСОВІ ВІДДІЛИ
-- ============================================================

INSERT INTO organizational_units (id, parent_id, code, name, level, unit_type, is_active, created_by) VALUES
(41, 40, 'FIN-ACC', 'Відділ бухгалтерії', 3, 'division', true, 'seed_data'),
(42, 40, 'FIN-PLAN', 'Відділ планування', 3, 'division', true, 'seed_data'),
(43, 40, 'FIN-CTRL', 'Відділ фінансового контролю', 3, 'division', true, 'seed_data');

-- ============================================================
-- РІВЕНЬ 4: КОМАНДИ В IT РОЗРОБЦІ
-- ============================================================

INSERT INTO organizational_units (id, parent_id, code, name, level, unit_type, is_active, created_by) VALUES
(311, 31, 'IT-DEV-FRONT', 'Frontend команда', 4, 'team', true, 'seed_data'),
(312, 31, 'IT-DEV-BACK', 'Backend команда', 4, 'team', true, 'seed_data'),
(313, 31, 'IT-DEV-MOBILE', 'Mobile команда', 4, 'team', true, 'seed_data'),
(314, 31, 'IT-DEV-QA', 'QA команда', 4, 'team', true, 'seed_data');

-- ============================================================
-- ОНОВИТИ full_path
-- ============================================================

-- Рівень 2
UPDATE organizational_units ou
SET full_path = (
    SELECT p.full_path || ' → ' || ou.name
    FROM organizational_units p
    WHERE p.id = ou.parent_id
)
WHERE ou.level = 2;

-- Рівень 3
UPDATE organizational_units ou
SET full_path = (
    SELECT p.full_path || ' → ' || ou.name
    FROM organizational_units p
    WHERE p.id = ou.parent_id
)
WHERE ou.level = 3;

-- Рівень 4
UPDATE organizational_units ou
SET full_path = (
    SELECT p.full_path || ' → ' || ou.name
    FROM organizational_units p
    WHERE p.id = ou.parent_id
)
WHERE ou.level = 4;

-- ============================================================
-- СТАТИСТИКА
-- ============================================================

SELECT 
    'Створено підрозділів' as info,
    COUNT(*) as total,
    COUNT(CASE WHEN level = 1 THEN 1 END) as companies,
    COUNT(CASE WHEN level = 2 THEN 1 END) as departments,
    COUNT(CASE WHEN level = 3 THEN 1 END) as divisions,
    COUNT(CASE WHEN level = 4 THEN 1 END) as teams
FROM organizational_units;

-- Показати дерево
SELECT 
    REPEAT('  ', level - 1) || name as hierarchy,
    code,
    level,
    unit_type,
    full_path
FROM organizational_units
ORDER BY full_path;