-- ============================================================
-- КОНТРАКТИ: Базові оклади для позицій
-- ============================================================

TRUNCATE contracts RESTART IDENTITY CASCADE;

-- Контракти для всіх 10 позицій
INSERT INTO contracts (position_id, contract_type, base_rate, currency, start_datetime, created_by) VALUES
-- Alex Storm (Sales East)
(1, 'salary', 25000.00, 'UAH', '2023-01-15 09:00:00+00', 'seed_data'),
-- Mira Vale (Sales West)
(2, 'salary', 26000.00, 'UAH', '2023-02-01 09:00:00+00', 'seed_data'),
-- Oren Pike (Accountant)
(3, 'salary', 35000.00, 'UAH', '2023-03-10 09:00:00+00', 'seed_data'),
-- Lina Frost (HR Manager)
(4, 'salary', 28000.00, 'UAH', '2023-04-15 09:00:00+00', 'seed_data'),
-- Dara Bloom (IT Support)
(5, 'salary', 30000.00, 'UAH', '2023-05-01 09:00:00+00', 'seed_data'),
-- Ilan West (Senior Dev)
(6, 'salary', 45000.00, 'UAH', '2023-06-01 09:00:00+00', 'seed_data'),
-- Rhea Stone (Marketing, 0.5 ставка!)
(7, 'salary', 24000.00, 'UAH', '2023-07-15 09:00:00+00', 'seed_data'),
-- Niko Reed (Operations Manager)
(8, 'salary', 32000.00, 'UAH', '2023-08-01 09:00:00+00', 'seed_data'),
-- Tara Quinn (Sales Head)
(9, 'salary', 40000.00, 'UAH', '2023-09-01 09:00:00+00', 'seed_data'),
-- Zane Brook (CEO Assistant)
(10, 'salary', 33000.00, 'UAH', '2023-10-01 09:00:00+00', 'seed_data');

-- Статистика
SELECT 
    'Створено контрактів' as info,
    COUNT(*) as total,
    AVG(base_rate)::numeric(10,2) as avg_salary,
    MIN(base_rate)::numeric(10,2) as min_salary,
    MAX(base_rate)::numeric(10,2) as max_salary
FROM contracts;

-- Показати контракти з працівниками
SELECT 
    e.personnel_number,
    e.first_name || ' ' || e.last_name as employee_name,
    p.position_name,
    c.base_rate,
    p.employment_rate,
    (c.base_rate * p.employment_rate)::numeric(10,2) as effective_salary,
    c.contract_type
FROM contracts c
JOIN positions p ON p.id = c.position_id
JOIN employees e ON e.id = p.employee_id
ORDER BY c.base_rate DESC;