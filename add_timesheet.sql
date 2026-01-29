-- Додавання табелю відпрацьованого часу для працівників за січень 2024

-- Працівники з окладом (salary) - стандартний робочий день 8 годин, 22 робочі дні
-- EMP001 (Alex Storm), EMP002 (Mira Vale), EMP005 (Dara Bloom), EMP006 (Ilan West), 
-- EMP007 (Rhea Stone), EMP008 (Niko Reed)

-- Працівники з погодинною оплатою (hourly) - різна кількість годин
-- EMP003 (Oren Pike), EMP004 (Lina Frost), EMP009 (Tara Quinn), EMP010 (Zane Brook)

-- Робочі дні січня 2024: 1-5, 8-12, 15-19, 22-26, 29-31 (22 дні)

-- Працівник 1: Alex Storm (salary) - повний місяць, 176 годин
INSERT INTO timesheets (employee_id, organizational_unit_id, work_date, hours_worked, minutes_worked, shift_type, status) 
SELECT 1, 5, date, 8, 0, 'day', 'confirmed'
FROM generate_series('2024-01-01'::date, '2024-01-31'::date, '1 day'::interval) AS date
WHERE EXTRACT(DOW FROM date) NOT IN (0, 6); -- Пн-Пт

-- Працівник 2: Mira Vale (salary) - повний місяць, 176 годин
INSERT INTO timesheets (employee_id, organizational_unit_id, work_date, hours_worked, minutes_worked, shift_type, status) 
SELECT 2, 5, date, 8, 0, 'day', 'confirmed'
FROM generate_series('2024-01-01'::date, '2024-01-31'::date, '1 day'::interval) AS date
WHERE EXTRACT(DOW FROM date) NOT IN (0, 6);

-- Працівник 3: Oren Pike (hourly) - 140 годин (варіабельний графік)
INSERT INTO timesheets (employee_id, organizational_unit_id, work_date, hours_worked, minutes_worked, shift_type, status) VALUES
(3, 6, '2024-01-02', 7, 30, 'day', 'confirmed'),
(3, 6, '2024-01-03', 8, 0, 'day', 'confirmed'),
(3, 6, '2024-01-04', 6, 0, 'day', 'confirmed'),
(3, 6, '2024-01-05', 9, 0, 'day', 'confirmed'),
(3, 6, '2024-01-08', 7, 0, 'day', 'confirmed'),
(3, 6, '2024-01-09', 8, 30, 'day', 'confirmed'),
(3, 6, '2024-01-10', 7, 0, 'day', 'confirmed'),
(3, 6, '2024-01-11', 8, 0, 'day', 'confirmed'),
(3, 6, '2024-01-12', 6, 30, 'day', 'confirmed'),
(3, 6, '2024-01-15', 8, 0, 'day', 'confirmed'),
(3, 6, '2024-01-16', 7, 30, 'day', 'confirmed'),
(3, 6, '2024-01-17', 9, 0, 'day', 'confirmed'),
(3, 6, '2024-01-18', 8, 0, 'day', 'confirmed'),
(3, 6, '2024-01-19', 7, 0, 'day', 'confirmed'),
(3, 6, '2024-01-22', 8, 30, 'day', 'confirmed'),
(3, 6, '2024-01-23', 7, 0, 'day', 'confirmed'),
(3, 6, '2024-01-24', 8, 0, 'day', 'confirmed'),
(3, 6, '2024-01-25', 6, 0, 'day', 'confirmed'),
(3, 6, '2024-01-26', 9, 0, 'day', 'confirmed'),
(3, 6, '2024-01-29', 8, 0, 'day', 'confirmed');

-- Працівник 4: Lina Frost (hourly) - 160 годин
INSERT INTO timesheets (employee_id, organizational_unit_id, work_date, hours_worked, minutes_worked, shift_type, status) 
SELECT 4, 6, date, 8, 0, 'day', 'confirmed'
FROM generate_series('2024-01-01'::date, '2024-01-31'::date, '1 day'::interval) AS date
WHERE EXTRACT(DOW FROM date) NOT IN (0, 6)
LIMIT 20; -- 20 днів по 8 годин

-- Працівник 5: Dara Bloom (salary) - повний місяць, 176 годин
INSERT INTO timesheets (employee_id, organizational_unit_id, work_date, hours_worked, minutes_worked, shift_type, status) 
SELECT 5, 7, date, 8, 0, 'day', 'confirmed'
FROM generate_series('2024-01-01'::date, '2024-01-31'::date, '1 day'::interval) AS date
WHERE EXTRACT(DOW FROM date) NOT IN (0, 6);

-- Працівник 6: Ilan West (salary) - 1 день лікарняний, 168 годин
INSERT INTO timesheets (employee_id, organizational_unit_id, work_date, hours_worked, minutes_worked, shift_type, status) 
SELECT 6, 7, date, 8, 0, 'day', 'confirmed'
FROM generate_series('2024-01-01'::date, '2024-01-31'::date, '1 day'::interval) AS date
WHERE EXTRACT(DOW FROM date) NOT IN (0, 6) AND date != '2024-01-15';

-- Працівник 7: Rhea Stone (salary) - повний місяць, 176 годин
INSERT INTO timesheets (employee_id, organizational_unit_id, work_date, hours_worked, minutes_worked, shift_type, status) 
SELECT 7, 8, date, 8, 0, 'day', 'confirmed'
FROM generate_series('2024-01-01'::date, '2024-01-31'::date, '1 day'::interval) AS date
WHERE EXTRACT(DOW FROM date) NOT IN (0, 6);

-- Працівник 8: Niko Reed (salary) - повний місяць + 2 дні переробки, 192 години
INSERT INTO timesheets (employee_id, organizational_unit_id, work_date, hours_worked, minutes_worked, shift_type, status) 
SELECT 8, 8, date, 8, 0, 'day', 'confirmed'
FROM generate_series('2024-01-01'::date, '2024-01-31'::date, '1 day'::interval) AS date
WHERE EXTRACT(DOW FROM date) NOT IN (0, 6);

-- Додаткові години (переробка)
INSERT INTO timesheets (employee_id, organizational_unit_id, work_date, hours_worked, minutes_worked, shift_type, status) VALUES
(8, 8, '2024-01-13', 4, 0, 'overtime', 'confirmed'),
(8, 8, '2024-01-27', 4, 0, 'overtime', 'confirmed');

-- Працівник 9: Tara Quinn (hourly) - 135 годин
INSERT INTO timesheets (employee_id, organizational_unit_id, work_date, hours_worked, minutes_worked, shift_type, status) VALUES
(9, 9, '2024-01-02', 7, 0, 'day', 'confirmed'),
(9, 9, '2024-01-03', 8, 0, 'day', 'confirmed'),
(9, 9, '2024-01-04', 7, 0, 'day', 'confirmed'),
(9, 9, '2024-01-05', 8, 0, 'day', 'confirmed'),
(9, 9, '2024-01-08', 7, 0, 'day', 'confirmed'),
(9, 9, '2024-01-09', 8, 0, 'day', 'confirmed'),
(9, 9, '2024-01-10', 7, 0, 'day', 'confirmed'),
(9, 9, '2024-01-11', 8, 0, 'day', 'confirmed'),
(9, 9, '2024-01-12', 7, 0, 'day', 'confirmed'),
(9, 9, '2024-01-15', 8, 0, 'day', 'confirmed'),
(9, 9, '2024-01-16', 7, 0, 'day', 'confirmed'),
(9, 9, '2024-01-17', 8, 0, 'day', 'confirmed'),
(9, 9, '2024-01-18', 7, 0, 'day', 'confirmed'),
(9, 9, '2024-01-19', 8, 0, 'day', 'confirmed'),
(9, 9, '2024-01-22', 7, 0, 'day', 'confirmed'),
(9, 9, '2024-01-23', 8, 0, 'day', 'confirmed'),
(9, 9, '2024-01-24', 7, 0, 'day', 'confirmed'),
(9, 9, '2024-01-25', 8, 0, 'day', 'confirmed');

-- Працівник 10: Zane Brook (hourly) - 152 години
INSERT INTO timesheets (employee_id, organizational_unit_id, work_date, hours_worked, minutes_worked, shift_type, status) 
SELECT 10, 10, date, 8, 0, 'day', 'confirmed'
FROM generate_series('2024-01-01'::date, '2024-01-31'::date, '1 day'::interval) AS date
WHERE EXTRACT(DOW FROM date) NOT IN (0, 6)
LIMIT 19; -- 19 днів по 8 годин

-- Статистика по табелю
SELECT 
    e.personnel_number,
    e.first_name || ' ' || e.last_name AS full_name,
    c.contract_type,
    COUNT(*) AS work_days,
    SUM(t.hours_worked + t.minutes_worked::decimal / 60) AS total_hours,
    CASE 
        WHEN c.contract_type = 'salary' THEN c.base_rate
        WHEN c.contract_type = 'hourly' THEN c.base_rate * SUM(t.hours_worked + t.minutes_worked::decimal / 60)
    END AS estimated_pay
FROM timesheets t
JOIN employees e ON t.employee_id = e.id
JOIN contracts c ON c.employee_id = e.id AND c.is_active = true
WHERE t.work_date >= '2024-01-01' AND t.work_date <= '2024-01-31'
GROUP BY e.id, e.personnel_number, e.first_name, e.last_name, c.contract_type, c.base_rate
ORDER BY e.personnel_number;
