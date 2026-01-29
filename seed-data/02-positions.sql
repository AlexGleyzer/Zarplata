-- Очистити старі дані
TRUNCATE positions RESTART IDENTITY CASCADE;

-- Позиції з НОВИМИ ID підрозділів
INSERT INTO positions (employee_id, organizational_unit_id, position_code, position_name, employment_rate, start_date, created_by) VALUES
-- EMP001 - Alex Storm (Sales East)
(1, 11, 'POS-001', 'Менеджер з продажу', 1.0, '2023-01-15', 'seed_data'),
-- EMP002 - Mira Vale (Sales West)
(2, 12, 'POS-002', 'Менеджер з продажу', 1.0, '2023-02-01', 'seed_data'),
-- EMP003 - Oren Pike (Finance - Accounting)
(3, 41, 'POS-003', 'Головний бухгалтер', 1.0, '2023-03-10', 'seed_data'),
-- EMP004 - Lina Frost (HR)
(4, 50, 'POS-004', 'HR менеджер', 1.0, '2023-04-15', 'seed_data'),
-- EMP005 - Dara Bloom (IT Support)
(5, 33, 'POS-005', 'IT спеціаліст', 1.0, '2023-05-01', 'seed_data'),
-- EMP006 - Ilan West (IT Development - Backend)
(6, 312, 'POS-006', 'Senior розробник', 1.0, '2023-06-01', 'seed_data'),
-- EMP007 - Rhea Stone (Marketing) - 50% ставка!
(7, 60, 'POS-007', 'Маркетолог', 0.5, '2023-07-15', 'seed_data'),
-- EMP008 - Niko Reed (Operations - Logistics)
(8, 21, 'POS-008', 'Операційний менеджер', 1.0, '2023-08-01', 'seed_data'),
-- EMP009 - Tara Quinn (Sales East - керівник)
(9, 11, 'POS-009', 'Керівник відділу продажів', 1.0, '2023-09-01', 'seed_data'),
-- EMP010 - Zane Brook (CEO Office / Root)
(10, 1, 'POS-010', 'Помічник директора', 1.0, '2023-10-01', 'seed_data');

-- Статистика
SELECT 
    'Створено позицій' as info,
    COUNT(*) as total,
    COUNT(CASE WHEN employment_rate = 1.0 THEN 1 END) as full_time,
    COUNT(CASE WHEN employment_rate < 1.0 THEN 1 END) as part_time
FROM positions;

-- Показати позиції з працівниками
SELECT 
    p.position_code,
    p.position_name,
    e.personnel_number,
    e.first_name || ' ' || e.last_name as employee_name,
    ou.name as department,
    ou.full_path,
    p.employment_rate
FROM positions p
JOIN employees e ON e.id = p.employee_id
JOIN organizational_units ou ON ou.id = p.organizational_unit_id
ORDER BY ou.full_path, p.id;