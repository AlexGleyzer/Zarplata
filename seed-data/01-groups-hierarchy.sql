-- ============================================================
-- ТЕСТОВІ ДАНІ: Дерево Груп
-- ============================================================

-- Очистити (обережно!)
TRUNCATE groups RESTART IDENTITY CASCADE;

-- Рівень 1: Корінь дерев
INSERT INTO groups (id, parent_id, code, name, level, group_type, is_active) VALUES
(1, NULL, 'BENEFITS', 'Пільгові категорії', 1, 'social', true),
(2, NULL, 'PROFESSIONAL', 'Професійні категорії', 1, 'professional', true),
(3, NULL, 'ADMINISTRATIVE', 'Адміністративні', 1, 'administrative', true);

-- Рівень 2: Підкатегорії пільг
INSERT INTO groups (id, parent_id, code, name, level, group_type, is_active) VALUES
(10, 1, 'DISABILITY', 'Інваліди', 2, 'social', true),
(11, 1, 'FAMILIES', 'Сім''ї з дітьми', 2, 'social', true),
(12, 1, 'VETERANS', 'Ветерани', 2, 'social', true);

-- Рівень 3: Конкретні групи інвалідності
INSERT INTO groups (id, parent_id, code, name, level, group_type, is_active) VALUES
(100, 10, 'DISABILITY_1', 'Інваліди 1 групи', 3, 'social', true),
(101, 10, 'DISABILITY_2', 'Інваліди 2 групи', 3, 'social', true),
(102, 10, 'DISABILITY_3', 'Інваліди 3 групи', 3, 'social', true);

-- Рівень 3: Типи сімей
INSERT INTO groups (id, parent_id, code, name, level, group_type, is_active) VALUES
(110, 11, 'LARGE_FAMILY', 'Багатодітні сім''ї (3+ дітей)', 3, 'social', true),
(111, 11, 'SINGLE_MOTHER', 'Матері-одиначки', 3, 'social', true),
(112, 11, 'SINGLE_FATHER', 'Батьки-одинаки', 3, 'social', true),
(113, 11, 'TWO_CHILDREN', 'Сім''ї з двома дітьми', 3, 'social', true);

-- Рівень 3: Типи ветеранів
INSERT INTO groups (id, parent_id, code, name, level, group_type, is_active) VALUES
(120, 12, 'VETERAN_WW2', 'Ветерани ВВВ', 3, 'social', true),
(121, 12, 'VETERAN_ATO', 'Ветерани АТО/ООС', 3, 'social', true),
(122, 12, 'COMBAT_PARTICIPANT', 'Учасники бойових дій', 3, 'social', true);

-- Рівень 2: Професійні підкатегорії
INSERT INTO groups (id, parent_id, code, name, level, group_type, is_active) VALUES
(20, 2, 'TEACHERS', 'Педагогічні працівники', 2, 'professional', true),
(21, 2, 'MANAGEMENT', 'Керівний склад', 2, 'professional', true),
(22, 2, 'TECHNICAL', 'Технічні спеціалісти', 2, 'professional', true);

-- Рівень 3: Конкретні педагогічні ролі
INSERT INTO groups (id, parent_id, code, name, level, group_type, is_active) VALUES
(200, 20, 'CLASS_TEACHER', 'Класні керівники', 3, 'professional', true),
(201, 20, 'ROOM_HEAD', 'Завідувачі кабінетів', 3, 'professional', true),
(202, 20, 'CLUB_LEADER', 'Керівники гуртків', 3, 'professional', true),
(203, 20, 'SUBJECT_TEACHER', 'Предметники', 3, 'professional', true),
(204, 20, 'YOUNG_SPECIALIST', 'Молоді спеціалісти', 3, 'professional', true);

-- Рівень 3: Керівні посади
INSERT INTO groups (id, parent_id, code, name, level, group_type, is_active) VALUES
(210, 21, 'DEPT_HEAD', 'Завідувачі кафедр', 3, 'professional', true),
(211, 21, 'DEPUTY_DIRECTOR', 'Заступники директора', 3, 'professional', true),
(212, 21, 'DIRECTOR', 'Директор', 3, 'professional', true);

-- Рівень 3: Технічні спеціалісти
INSERT INTO groups (id, parent_id, code, name, level, group_type, is_active) VALUES
(220, 22, 'IT_SPECIALIST', 'IT спеціалісти', 3, 'professional', true),
(221, 22, 'ENGINEER', 'Інженери', 3, 'professional', true);

-- Рівень 2: Адміністративні
INSERT INTO groups (id, parent_id, code, name, level, group_type, is_active) VALUES
(30, 3, 'UNION', 'Профспілка', 2, 'administrative', true),
(31, 3, 'PENSIONERS', 'Пенсіонери', 2, 'administrative', true);

-- Рівень 3: Підкатегорії
INSERT INTO groups (id, parent_id, code, name, level, group_type, is_active) VALUES
(300, 30, 'UNION_MEMBER', 'Члени профспілки', 3, 'administrative', true),
(301, 30, 'UNION_LEADER', 'Профспілковий актив', 3, 'administrative', true),
(310, 31, 'PENSIONER_WORKING', 'Працюючі пенсіонери', 3, 'administrative', true);

-- Оновити full_path для рівня 1
UPDATE groups SET full_path = name WHERE parent_id IS NULL;

-- Оновити full_path для рівня 2
UPDATE groups g 
SET full_path = p.full_path || ' → ' || g.name
FROM groups p
WHERE g.parent_id = p.id AND g.level = 2;

-- Оновити full_path для рівня 3
UPDATE groups g 
SET full_path = p.full_path || ' → ' || g.name
FROM groups p
WHERE g.parent_id = p.id AND g.level = 3;

-- Перевірка: показати дерево
SELECT 
    REPEAT('  ', level - 1) || name as hierarchy,
    code,
    level,
    group_type,
    full_path
FROM groups
ORDER BY 
    CASE 
        WHEN group_type = 'social' THEN 1
        WHEN group_type = 'professional' THEN 2
        WHEN group_type = 'administrative' THEN 3
    END,
    full_path;

-- Статистика
SELECT 
    group_type,
    COUNT(*) as total,
    COUNT(CASE WHEN level = 1 THEN 1 END) as level_1,
    COUNT(CASE WHEN level = 2 THEN 1 END) as level_2,
    COUNT(CASE WHEN level = 3 THEN 1 END) as level_3
FROM groups
GROUP BY group_type
ORDER BY group_type;