-- ============================================================
-- ПРИЗНАЧЕННЯ НА ГРУПИ: Хто до яких груп належить
-- ============================================================

TRUNCATE position_groups RESTART IDENTITY CASCADE;

-- Alex Storm (POS-001) - Інвалід 2 групи
INSERT INTO position_groups (position_id, group_id, valid_from, document_number, created_by) VALUES
(1, 101, '2023-01-15 00:00:00+00', 'DOC-2023-001', 'seed_data');

-- Mira Vale (POS-002) - Багатодітна сім'я (3 дитини)
INSERT INTO position_groups (position_id, group_id, valid_from, document_number, created_by) VALUES
(2, 110, '2023-02-01 00:00:00+00', 'DOC-2023-002', 'seed_data');

-- Oren Pike (POS-003) - Ветеран АТО
INSERT INTO position_groups (position_id, group_id, valid_from, document_number, created_by) VALUES
(3, 121, '2023-03-10 00:00:00+00', 'DOC-2023-003', 'seed_data');

-- Lina Frost (POS-004) - Мати-одиначка
INSERT INTO position_groups (position_id, group_id, valid_from, document_number, created_by) VALUES
(4, 111, '2023-04-15 00:00:00+00', 'DOC-2023-004', 'seed_data');

-- Dara Bloom (POS-005) - Класний керівник
INSERT INTO position_groups (position_id, group_id, valid_from, document_number, created_by) VALUES
(5, 200, '2023-05-01 00:00:00+00', 'DOC-2023-005', 'seed_data');

-- Ilan West (POS-006) - Молодий спеціаліст + Член профспілки
INSERT INTO position_groups (position_id, group_id, valid_from, document_number, created_by) VALUES
(6, 204, '2023-06-01 00:00:00+00', 'DOC-2023-006', 'seed_data'),
(6, 300, '2023-06-01 00:00:00+00', 'DOC-2023-006', 'seed_data');

-- Rhea Stone (POS-007) - Працюючий пенсіонер (0.5 ставки!)
INSERT INTO position_groups (position_id, group_id, valid_from, document_number, created_by) VALUES
(7, 310, '2023-07-15 00:00:00+00', 'DOC-2023-007', 'seed_data');

-- Niko Reed (POS-008) - Сім'я з двома дітьми
INSERT INTO position_groups (position_id, group_id, valid_from, document_number, created_by) VALUES
(8, 113, '2023-08-01 00:00:00+00', 'DOC-2023-008', 'seed_data');

-- Tara Quinn (POS-009) - Заступник директора + Завідувач кафедри
INSERT INTO position_groups (position_id, group_id, valid_from, document_number, created_by) VALUES
(9, 211, '2023-09-01 00:00:00+00', 'DOC-2023-009', 'seed_data'),
(9, 210, '2023-09-01 00:00:00+00', 'DOC-2023-009', 'seed_data');

-- Zane Brook (POS-010) - БЕЗ ПІЛЬГ (чистий випадок для порівняння)
-- Нічого не додаємо

-- Статистика
SELECT 
    'Призначено на групи' as info,
    COUNT(*) as total_assignments,
    COUNT(DISTINCT position_id) as positions_with_groups,
    10 - COUNT(DISTINCT position_id) as positions_without_groups
FROM position_groups;

-- Показати хто в яких групах
SELECT 
    e.personnel_number,
    e.first_name || ' ' || e.last_name as employee_name,
    p.position_name,
    g.name as group_name,
    g.full_path,
    pg.document_number
FROM position_groups pg
JOIN positions p ON p.id = pg.position_id
JOIN employees e ON e.id = p.employee_id
JOIN groups g ON g.id = pg.group_id
ORDER BY e.personnel_number, g.full_path;

-- Групи по типах
SELECT 
    g.group_type,
    COUNT(DISTINCT pg.position_id) as employees_count
FROM position_groups pg
JOIN groups g ON g.id = pg.group_id
GROUP BY g.group_type
ORDER BY g.group_type;