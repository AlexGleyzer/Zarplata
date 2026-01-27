-- ============================================================================
-- ТЕСТОВІ ДАНІ ДЛЯ СИСТЕМИ "ZARPLATA"
-- ============================================================================

-- ============================================================================
-- БЛОК 1: БАЗОВІ ДОВІДНИКИ
-- ============================================================================

-- Типи робочого часу
INSERT INTO work_time_types (code, name, short_name, category, pay_coefficient, counts_as_worked, requires_document, color, sort_order) VALUES
('normal', 'Норма', 'Н', 'work', 1.0, 1, 0, '#4CAF50', 1),
('overtime', 'Понаднормові', 'П', 'work', 1.5, 1, 0, '#FF9800', 2),
('night', 'Нічні години', 'НЧ', 'work', 1.2, 1, 0, '#9C27B0', 3),
('weekend', 'Робота у вихідні', 'ВХ', 'work', 2.0, 1, 0, '#E91E63', 4),
('holiday', 'Святкові дні', 'СВ', 'work', 2.0, 1, 0, '#F44336', 5),
('vacation', 'Відпустка', 'В', 'paid_leave', 1.0, 0, 1, '#2196F3', 10),
('vacation_extra', 'Додаткова відпустка', 'ДВ', 'paid_leave', 1.0, 0, 1, '#03A9F4', 11),
('sick', 'Лікарняний', 'Л', 'paid_leave', 0.6, 0, 1, '#00BCD4', 12),
('unpaid', 'За свій рахунок', 'ЗС', 'unpaid_leave', 0, 0, 1, '#607D8B', 20),
('business_trip', 'Відрядження', 'ВД', 'work', 1.0, 1, 1, '#795548', 15),
('absence', 'Прогул', 'ПР', 'absence', 0, 0, 0, '#F44336', 30);

-- Модулі розрахунку
INSERT INTO calculation_modules (code, name, description, primary_table, formula_template) VALUES
('hourly', 'Погодинна оплата', 'Оплата за фактично відпрацьовані години', 'doc_timesheet_records', 'hours * hourly_rate * coefficient'),
('salary', 'Місячний оклад', 'Фіксований оклад за місяць', 'doc_timesheet_records', 'base_salary * (worked_hours / norm_hours)'),
('piecework', 'Відрядна', 'Оплата за кількість виробленої продукції', 'doc_piecework_production', 'quantity * rate_per_unit'),
('piecework_bonus', 'Відрядно-преміальна', 'Відрядна з премією за перевиконання', 'doc_piecework_production', 'quantity * rate + bonus'),
('task', 'Акордна', 'Оплата за виконання завдання', 'doc_task_completion', 'task_amount * completion_percent');

-- Шаблони графіків роботи
INSERT INTO work_time_templates (code, name, description, template_type, is_default, settings) VALUES
('5_2_standard', '5/2 стандартний', 'Пн-Пт 09:00-18:00, Сб-Нд вихідні', 'standard', 1, '{"work_days":[1,2,3,4,5],"hours_per_day":8,"start_time":"09:00","end_time":"18:00","lunch_break":60}'),
('5_2_early', '5/2 ранній', 'Пн-Пт 08:00-17:00, Сб-Нд вихідні', 'standard', 0, '{"work_days":[1,2,3,4,5],"hours_per_day":8,"start_time":"08:00","end_time":"17:00","lunch_break":60}'),
('2_2_day', '2/2 денна зміна', '2 дні роботи, 2 вихідних (12 год)', 'shift', 0, '{"pattern":"2-2","hours_per_shift":12,"start_time":"08:00","end_time":"20:00"}'),
('2_2_night', '2/2 нічна зміна', '2 ночі роботи, 2 вихідних (12 год)', 'shift', 0, '{"pattern":"2-2","hours_per_shift":12,"start_time":"20:00","end_time":"08:00","is_night":true}'),
('flexible', 'Гнучкий графік', 'Норма годин на тиждень, час довільний', 'flexible', 0, '{"weekly_hours":40,"min_hours_per_day":4,"max_hours_per_day":10}'),
('remote', 'Дистанційна робота', 'Віддалена робота, гнучкий графік', 'flexible', 0, '{"weekly_hours":40,"is_remote":true}');

-- Дні для стандартного графіка 5/2
INSERT INTO work_time_template_days (template_id, day_of_week, is_work_day, hours, start_time, end_time, break_minutes) VALUES
(1, 1, 1, 8, '09:00', '18:00', 60),
(1, 2, 1, 8, '09:00', '18:00', 60),
(1, 3, 1, 8, '09:00', '18:00', 60),
(1, 4, 1, 8, '09:00', '18:00', 60),
(1, 5, 1, 8, '09:00', '18:00', 60),
(1, 6, 0, 0, NULL, NULL, 0),
(1, 7, 0, 0, NULL, NULL, 0);

-- Типи нарахувань
INSERT INTO accrual_types (code, name, category, is_taxable, is_included_in_average, calculation_order, is_system) VALUES
('base_salary', 'Основна заробітна плата', 'salary', 1, 1, 10, 1),
('overtime_pay', 'Оплата понаднормових', 'salary', 1, 1, 20, 1),
('night_pay', 'Доплата за нічні години', 'salary', 1, 1, 21, 1),
('weekend_pay', 'Оплата роботи у вихідні', 'salary', 1, 1, 22, 1),
('holiday_pay', 'Оплата святкових днів', 'salary', 1, 1, 23, 1),
('bonus_monthly', 'Місячна премія', 'bonus', 1, 1, 30, 0),
('bonus_quarterly', 'Квартальна премія', 'bonus', 1, 1, 31, 0),
('bonus_yearly', 'Річна премія', 'bonus', 1, 1, 32, 0),
('bonus_onetime', 'Разова премія', 'bonus', 1, 0, 33, 0),
('allowance_harmful', 'Надбавка за шкідливість', 'allowance', 1, 1, 40, 0),
('allowance_intensity', 'Надбавка за інтенсивність', 'allowance', 1, 1, 41, 0),
('allowance_qualification', 'Надбавка за кваліфікацію', 'allowance', 1, 1, 42, 0),
('vacation_pay', 'Відпускні', 'vacation', 1, 0, 50, 1),
('sick_pay', 'Лікарняні', 'sick', 1, 0, 51, 1),
('compensation_travel', 'Компенсація проїзду', 'compensation', 0, 0, 60, 0),
('compensation_meals', 'Компенсація харчування', 'compensation', 0, 0, 61, 0),
('compensation_mobile', 'Компенсація мобільного зв''язку', 'compensation', 0, 0, 62, 0);

-- Типи утримань
INSERT INTO deduction_types (code, name, category, calculation_base, is_mandatory, calculation_order, is_system) VALUES
('pdfo', 'ПДФО (18%)', 'tax', 'taxable_income', 1, 10, 1),
('military', 'Військовий збір (1.5%)', 'tax', 'taxable_income', 1, 11, 1),
('esv', 'ЄСВ (22%)', 'social', 'total_accrued', 1, 20, 1),
('alimony', 'Аліменти', 'executive', 'net_income', 0, 30, 0),
('alimony_percent', 'Аліменти (%)', 'executive', 'net_income', 0, 31, 0),
('loan', 'Погашення позики', 'voluntary', 'fixed', 0, 40, 0),
('union', 'Профспілкові внески', 'voluntary', 'total_accrued', 0, 41, 0),
('insurance', 'Страхування', 'voluntary', 'fixed', 0, 42, 0),
('advance', 'Утримання авансу', 'other', 'fixed', 0, 50, 0);

-- Категорії працівників
INSERT INTO employee_categories (code, name, description, category_type, affects_taxes, affects_accruals) VALUES
('disabled_1', 'Інвалід 1 групи', 'Інвалід першої групи', 'social', 1, 1),
('disabled_2', 'Інвалід 2 групи', 'Інвалід другої групи', 'social', 1, 1),
('disabled_3', 'Інвалід 3 групи', 'Інвалід третьої групи', 'social', 1, 0),
('chernobyl_1', 'Чорнобилець 1 категорії', 'Постраждалий від ЧАЕС 1 кат.', 'social', 1, 1),
('chernobyl_2', 'Чорнобилець 2 категорії', 'Постраждалий від ЧАЕС 2 кат.', 'social', 1, 1),
('veteran', 'Ветеран праці', 'Ветеран праці', 'social', 0, 1),
('single_parent', 'Одинокий батько/мати', 'Одинокий батько або мати', 'social', 1, 0),
('many_children', 'Багатодітний', 'Має 3 і більше дітей', 'social', 1, 0),
('young_specialist', 'Молодий спеціаліст', 'До 35 років, перше місце роботи', 'professional', 0, 1),
('key_employee', 'Ключовий спеціаліст', 'Важливий для компанії працівник', 'professional', 0, 1),
('probation', 'На випробувальному терміні', 'Випробувальний термін', 'professional', 0, 1);

-- ============================================================================
-- БЛОК 2: РОЛІ ТА ДОЗВОЛИ
-- ============================================================================

-- Ролі
INSERT INTO roles (code, name, description, is_system) VALUES
('admin', 'Адміністратор', 'Повний доступ до системи', 1),
('director', 'Директор', 'Керівник підприємства', 1),
('chief_accountant', 'Головний бухгалтер', 'Головний бухгалтер', 1),
('accountant', 'Бухгалтер', 'Бухгалтер з нарахування ЗП', 1),
('hr_manager', 'HR-менеджер', 'Менеджер з персоналу', 1),
('dept_head', 'Начальник відділу', 'Керівник підрозділу', 0),
('employee', 'Працівник', 'Звичайний працівник (перегляд своїх даних)', 0),
('auditor', 'Аудитор', 'Тільки перегляд', 0);

-- Дозволи
INSERT INTO permissions (code, name, category, description) VALUES
-- Працівники
('employees_view', 'Перегляд працівників', 'employees', 'Перегляд списку працівників'),
('employees_edit', 'Редагування працівників', 'employees', 'Створення/редагування працівників'),
('employees_delete', 'Видалення працівників', 'employees', 'Видалення працівників'),
('employees_salary_view', 'Перегляд зарплат', 'employees', 'Перегляд даних про зарплату'),
-- Документи
('documents_create', 'Створення документів', 'documents', 'Створення нових документів'),
('documents_edit', 'Редагування документів', 'documents', 'Редагування чернеток'),
('documents_post', 'Проведення документів', 'documents', 'Проведення документів'),
('documents_unpost', 'Скасування проведення', 'documents', 'Скасування проведення'),
('documents_approve', 'Погодження документів', 'documents', 'Погодження документів'),
('documents_sign', 'Підпис документів', 'documents', 'Підпис документів'),
-- Розрахунки
('calculations_run', 'Запуск розрахунків', 'calculations', 'Запуск нарахування ЗП'),
('calculations_view', 'Перегляд розрахунків', 'calculations', 'Перегляд результатів'),
-- Звіти
('reports_view', 'Перегляд звітів', 'reports', 'Перегляд звітів'),
('reports_export', 'Експорт звітів', 'reports', 'Експорт в Excel/PDF'),
-- Налаштування
('settings_view', 'Перегляд налаштувань', 'settings', 'Перегляд налаштувань'),
('settings_edit', 'Редагування налаштувань', 'settings', 'Зміна налаштувань'),
-- Права доступу
('access_manage', 'Керування правами', 'access', 'Надання/відкликання прав');

-- Дозволи ролей
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p WHERE r.code = 'admin';

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'director' AND p.code IN ('employees_view', 'employees_salary_view', 'documents_approve', 'documents_sign', 'calculations_view', 'reports_view', 'reports_export');

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'chief_accountant' AND p.code IN ('employees_view', 'employees_salary_view', 'documents_create', 'documents_edit', 'documents_post', 'documents_approve', 'calculations_run', 'calculations_view', 'reports_view', 'reports_export');

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'accountant' AND p.code IN ('employees_view', 'employees_salary_view', 'documents_create', 'documents_edit', 'calculations_run', 'calculations_view', 'reports_view');

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'hr_manager' AND p.code IN ('employees_view', 'employees_edit', 'documents_create', 'documents_edit', 'reports_view');

-- ============================================================================
-- БЛОК 3: ОРГАНІЗАЦІЙНА СТРУКТУРА
-- ============================================================================

-- Підрозділи
INSERT INTO departments (code, name, full_name, level, sort_order, parent_id) VALUES
('ADMIN', 'Адміністрація', 'Адміністрація підприємства', 0, 1, NULL),
('FIN', 'Фінансовий департамент', 'Фінансовий департамент', 0, 2, NULL),
('IT', 'IT-департамент', 'Департамент інформаційних технологій', 0, 3, NULL),
('PROD', 'Виробництво', 'Виробничий департамент', 0, 4, NULL),
('SALES', 'Продажі', 'Департамент продажів', 0, 5, NULL);

-- Дочірні підрозділи
INSERT INTO departments (code, name, full_name, level, sort_order, parent_id) VALUES
('FIN_ACC', 'Бухгалтерія', 'Відділ бухгалтерії', 1, 1, 2),
('FIN_PLAN', 'Планово-економічний відділ', 'Планово-економічний відділ', 1, 2, 2),
('IT_DEV', 'Розробка', 'Відділ розробки ПЗ', 1, 1, 3),
('IT_QA', 'Тестування', 'Відділ тестування', 1, 2, 3),
('IT_DEVOPS', 'DevOps', 'Відділ DevOps', 1, 3, 3),
('IT_SUPPORT', 'Підтримка', 'Відділ технічної підтримки', 1, 4, 3),
('PROD_SHOP1', 'Цех №1', 'Виробничий цех №1', 1, 1, 4),
('PROD_SHOP2', 'Цех №2', 'Виробничий цех №2', 1, 2, 4),
('PROD_QC', 'Контроль якості', 'Відділ контролю якості', 1, 3, 4);

-- Оновлення full_path
UPDATE departments SET full_path = name WHERE parent_id IS NULL;
UPDATE departments SET full_path = (SELECT p.name FROM departments p WHERE p.id = departments.parent_id) || '/' || name WHERE parent_id IS NOT NULL;

-- Посади
INSERT INTO positions (code, name, category, min_salary, max_salary) VALUES
('DIR', 'Директор', 'management', 80000, 150000),
('DEP_HEAD', 'Начальник відділу', 'management', 50000, 90000),
('CHIEF_ACC', 'Головний бухгалтер', 'specialist', 45000, 75000),
('ACC', 'Бухгалтер', 'specialist', 25000, 45000),
('SENIOR_DEV', 'Senior Developer', 'specialist', 60000, 120000),
('MIDDLE_DEV', 'Middle Developer', 'specialist', 40000, 70000),
('JUNIOR_DEV', 'Junior Developer', 'specialist', 20000, 40000),
('QA_ENGINEER', 'QA Engineer', 'specialist', 30000, 60000),
('DEVOPS', 'DevOps Engineer', 'specialist', 50000, 90000),
('PM', 'Project Manager', 'management', 50000, 90000),
('HR', 'HR Manager', 'specialist', 30000, 55000),
('SALES_MGR', 'Менеджер з продажів', 'specialist', 25000, 50000),
('WORKER', 'Робітник', 'worker', 15000, 30000),
('MASTER', 'Майстер', 'specialist', 25000, 45000),
('QC_INSPECTOR', 'Контролер ВТК', 'specialist', 20000, 35000),
('SUPPORT', 'Спеціаліст підтримки', 'specialist', 20000, 40000);

-- ============================================================================
-- БЛОК 4: ПРАЦІВНИКИ
-- ============================================================================

-- Користувачі (паролі: hash для "password123")
INSERT INTO users (username, password_hash, email, is_admin) VALUES
('admin', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/X4', 'admin@company.com', 1),
('director', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/X4', 'director@company.com', 0),
('chief_acc', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/X4', 'chief.acc@company.com', 0),
('accountant1', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/X4', 'acc1@company.com', 0),
('hr_manager', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/X4', 'hr@company.com', 0);

-- Працівники
INSERT INTO employees (personnel_number, last_name, first_name, middle_name, birth_date, gender, tax_id, hire_date, phone, email) VALUES
('0001', 'Петренко', 'Іван', 'Миколайович', '1975-05-15', 'M', '1234567890', '2015-01-10', '+380501234567', 'petenko@company.com'),
('0002', 'Коваленко', 'Олена', 'Петрівна', '1982-08-22', 'F', '2345678901', '2018-03-15', '+380502345678', 'kovalenko@company.com'),
('0003', 'Шевченко', 'Андрій', 'Васильович', '1988-11-03', 'M', '3456789012', '2019-07-01', '+380503456789', 'shevchenko@company.com'),
('0004', 'Бондаренко', 'Марія', 'Олександрівна', '1990-02-14', 'F', '4567890123', '2020-01-15', '+380504567890', 'bondarenko@company.com'),
('0005', 'Мельник', 'Олександр', 'Сергійович', '1985-07-28', 'M', '5678901234', '2017-05-20', '+380505678901', 'melnyk@company.com'),
('0006', 'Ткаченко', 'Наталія', 'Ігорівна', '1992-04-10', 'F', '6789012345', '2021-02-01', '+380506789012', 'tkachenko@company.com'),
('0007', 'Кравченко', 'Дмитро', 'Олегович', '1987-12-05', 'M', '7890123456', '2016-09-10', '+380507890123', 'kravchenko@company.com'),
('0008', 'Іваненко', 'Тетяна', 'Андріївна', '1995-06-18', 'F', '8901234567', '2022-03-01', '+380508901234', 'ivanenko@company.com'),
('0009', 'Сидоренко', 'Максим', 'Юрійович', '1983-09-25', 'M', '9012345678', '2014-11-15', '+380509012345', 'sydorenko@company.com'),
('0010', 'Павленко', 'Ольга', 'Миколаївна', '1991-01-30', 'F', '0123456789', '2019-04-01', '+380500123456', 'pavlenko@company.com'),
('0011', 'Григоренко', 'Віктор', 'Петрович', '1980-03-12', 'M', '1122334455', '2010-08-01', '+380501122334', 'grygorenko@company.com'),
('0012', 'Савченко', 'Юлія', 'Вікторівна', '1994-10-08', 'F', '2233445566', '2021-06-15', '+380502233445', 'savchenko@company.com'),
('0013', 'Лисенко', 'Артем', 'Романович', '1989-05-20', 'M', '3344556677', '2018-01-10', '+380503344556', 'lysenko@company.com'),
('0014', 'Мороз', 'Катерина', 'Олексіївна', '1993-08-15', 'F', '4455667788', '2020-09-01', '+380504455667', 'moroz@company.com'),
('0015', 'Романенко', 'Сергій', 'Ігорович', '1986-11-28', 'M', '5566778899', '2015-04-15', '+380505566778', 'romanenko@company.com');

-- Зв'язок користувачів з працівниками
UPDATE users SET employee_id = 1 WHERE username = 'director';
UPDATE users SET employee_id = 2 WHERE username = 'chief_acc';
UPDATE users SET employee_id = 3 WHERE username = 'accountant1';
UPDATE users SET employee_id = 5 WHERE username = 'hr_manager';

-- Призначення працівників
INSERT INTO employee_assignments (employee_id, department_id, position_id, assignment_type, calculation_module_id, rate, base_salary, hourly_rate, start_date) VALUES
(1, 1, 1, 'primary', 2, 1.0, 120000, NULL, '2015-01-10'),  -- Директор
(2, 6, 3, 'primary', 2, 1.0, 65000, NULL, '2018-03-15'),   -- Головбух
(3, 6, 4, 'primary', 2, 1.0, 35000, NULL, '2019-07-01'),   -- Бухгалтер
(4, 6, 4, 'primary', 2, 1.0, 32000, NULL, '2020-01-15'),   -- Бухгалтер
(5, 1, 11, 'primary', 2, 1.0, 45000, NULL, '2017-05-20'),  -- HR
(6, 8, 5, 'primary', 2, 1.0, 95000, NULL, '2021-02-01'),   -- Senior Dev
(7, 8, 6, 'primary', 2, 1.0, 60000, NULL, '2016-09-10'),   -- Middle Dev
(8, 8, 7, 'primary', 2, 1.0, 30000, NULL, '2022-03-01'),   -- Junior Dev
(9, 9, 8, 'primary', 2, 1.0, 50000, NULL, '2014-11-15'),   -- QA
(10, 10, 9, 'primary', 2, 1.0, 75000, NULL, '2019-04-01'), -- DevOps
(11, 12, 14, 'primary', 3, 1.0, NULL, 180, '2010-08-01'),  -- Майстер цеху (відрядна)
(12, 12, 13, 'primary', 3, 1.0, NULL, 120, '2021-06-15'), -- Робітник (відрядна)
(13, 13, 13, 'primary', 3, 1.0, NULL, 130, '2018-01-10'), -- Робітник
(14, 14, 15, 'primary', 2, 1.0, 28000, NULL, '2020-09-01'), -- Контролер ВТК
(15, 11, 16, 'primary', 2, 1.0, 32000, NULL, '2015-04-15'); -- Спеціаліст підтримки

-- Графіки роботи
INSERT INTO employee_work_schedules (employee_id, assignment_id, template_id, start_date, reason) VALUES
(1, 1, 1, '2015-01-10', 'Прийом на роботу'),
(2, 2, 1, '2018-03-15', 'Прийом на роботу'),
(3, 3, 1, '2019-07-01', 'Прийом на роботу'),
(4, 4, 1, '2020-01-15', 'Прийом на роботу'),
(5, 5, 1, '2017-05-20', 'Прийом на роботу'),
(6, 6, 5, '2021-02-01', 'Гнучкий графік'),
(7, 7, 5, '2016-09-10', 'Гнучкий графік'),
(8, 8, 1, '2022-03-01', 'Прийом на роботу'),
(9, 9, 1, '2014-11-15', 'Прийом на роботу'),
(10, 10, 6, '2019-04-01', 'Дистанційна робота'),
(11, 11, 3, '2010-08-01', 'Змінний графік'),
(12, 12, 3, '2021-06-15', 'Змінний графік'),
(13, 13, 3, '2018-01-10', 'Змінний графік'),
(14, 14, 1, '2020-09-01', 'Прийом на роботу'),
(15, 15, 1, '2015-04-15', 'Прийом на роботу');

-- ============================================================================
-- БЛОК 5: ПРАВИЛА НАРАХУВАНЬ
-- ============================================================================

-- Шаблони правил
INSERT INTO accrual_rule_templates (code, name, accrual_type_id, category, formula, default_params, level) VALUES
-- Системні правила (законодавство)
('overtime_150', 'Понаднормові 150%', 2, 'time_based', 'hours * hourly_rate * 1.5', '{"coefficient": 1.5}', 'system'),
('night_120', 'Нічні 120%', 3, 'time_based', 'hours * hourly_rate * 1.2', '{"coefficient": 1.2}', 'system'),
('weekend_200', 'Вихідні 200%', 4, 'time_based', 'hours * hourly_rate * 2.0', '{"coefficient": 2.0}', 'system'),
('holiday_200', 'Святкові 200%', 5, 'time_based', 'hours * hourly_rate * 2.0', '{"coefficient": 2.0}', 'system'),
-- Правила підприємства
('bonus_monthly_15', 'Місячна премія 15%', 6, 'performance_based', 'base_salary * 0.15', '{"percent": 15}', 'company'),
('bonus_quarterly_25', 'Квартальна премія 25%', 7, 'performance_based', 'quarterly_salary * 0.25', '{"percent": 25}', 'company'),
-- Правила для IT-підрозділу
('overtime_it_170', 'Понаднормові IT 170%', 2, 'time_based', 'hours * hourly_rate * 1.7', '{"coefficient": 1.7}', 'department'),
('bonus_it_20', 'Премія IT 20%', 6, 'performance_based', 'base_salary * 0.20', '{"percent": 20}', 'department'),
-- Правила для посади Senior
('overtime_senior_180', 'Понаднормові Senior 180%', 2, 'time_based', 'hours * hourly_rate * 1.8', '{"coefficient": 1.8}', 'position'),
-- Правила для категорії "Ключовий спеціаліст"
('overtime_key_190', 'Понаднормові Key 190%', 2, 'time_based', 'hours * hourly_rate * 1.9', '{"coefficient": 1.9}', 'category');

-- Призначення правил
INSERT INTO accrual_assignments (rule_template_id, scope_type, scope_id, valid_from, priority) VALUES
-- Системні правила для всіх
(1, 'enterprise', NULL, '2020-01-01', 10),
(2, 'enterprise', NULL, '2020-01-01', 10),
(3, 'enterprise', NULL, '2020-01-01', 10),
(4, 'enterprise', NULL, '2020-01-01', 10),
-- Правила підприємства
(5, 'enterprise', NULL, '2020-01-01', 20),
(6, 'enterprise', NULL, '2020-01-01', 20),
-- Правила IT-підрозділу
(7, 'department', 3, '2020-01-01', 30),
(8, 'department', 3, '2020-01-01', 30),
-- Правила для Senior Dev
(9, 'position', 5, '2020-01-01', 40);

-- ============================================================================
-- БЛОК 6: КОМАНДНИЙ ІНТЕРФЕЙС
-- ============================================================================

-- Активні модулі
INSERT INTO company_modules (module_code, module_name, description, settings) VALUES
('payroll', 'Зарплата', 'Основний модуль нарахування ЗП', '{"enabled": true}'),
('timesheet', 'Табель', 'Облік робочого часу', '{"enabled": true}'),
('piecework', 'Відрядна', 'Відрядна оплата праці', '{"enabled": true}'),
('payments', 'Виплати', 'Модуль виплат', '{"enabled": true}'),
('reports', 'Звіти', 'Модуль звітності', '{"enabled": true}');

-- Кроки команд
INSERT INTO command_steps (step_key, parent_step, label, next_step_type, next_step_source, icon, sort_order) VALUES
-- Головні дії
('action', NULL, 'Дія', 'static', NULL, NULL, 1),
-- Типи після "Нарахувати"
('calc_type', 'action', 'Що нарахувати', 'static', NULL, NULL, 1),
-- Типи премій
('bonus_type', 'calc_type', 'Тип премії', 'static', NULL, NULL, 1),
-- Scope
('scope', NULL, 'Для кого', 'static', NULL, NULL, 2),
-- Вибір підрозділу
('select_department', 'scope', 'Підрозділ', 'dynamic', 'departments', NULL, 1),
-- Вибір працівника
('select_employee', 'scope', 'Працівник', 'dynamic', 'employees', NULL, 1),
-- Введення суми
('enter_amount', NULL, 'Сума', 'input', 'number', NULL, 3),
-- Фінальний крок
('confirm', NULL, 'Підтвердити', 'final', NULL, NULL, 100);

-- Опції для кроків
INSERT INTO command_step_options (step_key, option_id, option_label, next_step, icon, sort_order) VALUES
-- Дії
('action', 'calculate', 'Нарахувати', 'calc_type', '💰', 1),
('action', 'create_period', 'Створити період', 'period_type', '📅', 2),
('action', 'create_payment', 'Виплатити', 'payment_type', '💳', 3),
('action', 'create_timesheet', 'Табель', 'scope', '⏰', 4),
('action', 'view_report', 'Звіт', 'report_type', '📊', 5),
-- Типи нарахувань
('calc_type', 'salary', 'Зарплату', 'scope', '💵', 1),
('calc_type', 'bonus', 'Премію', 'bonus_type', '🎁', 2),
('calc_type', 'allowance', 'Надбавку', 'allowance_type', '➕', 3),
('calc_type', 'vacation', 'Відпускні', 'scope', '🏖️', 4),
('calc_type', 'sick', 'Лікарняні', 'scope', '🏥', 5),
-- Типи премій
('bonus_type', 'monthly', 'Місячна премія', 'scope', NULL, 1),
('bonus_type', 'quarterly', 'Квартальна премія', 'scope', NULL, 2),
('bonus_type', 'yearly', 'Річна премія', 'scope', NULL, 3),
('bonus_type', 'onetime', 'Разова премія', 'scope', NULL, 4),
('bonus_type', 'project', 'Проєктна премія', 'scope', NULL, 5),
-- Scope
('scope', 'enterprise', 'Все підприємство', 'enter_amount', '🏢', 1),
('scope', 'department', 'Підрозділ', 'select_department', '🏛️', 2),
('scope', 'position', 'Посада', 'select_position', '💼', 3),
('scope', 'category', 'Категорія', 'select_category', '👥', 4),
('scope', 'employee', 'Людина', 'select_employee', '👤', 5);

-- ============================================================================
-- БЛОК 7: ТЕСТОВИЙ ПЕРІОД ТА ДОКУМЕНТИ
-- ============================================================================

-- Розрахунковий період
INSERT INTO payroll_periods (period_type, name, start_date, end_date, work_days, work_hours, scope_type, status) VALUES
('month', 'Січень 2024', '2024-01-01', '2024-01-31', 22, 176, 'enterprise', 'open'),
('month', 'Лютий 2024', '2024-02-01', '2024-02-29', 21, 168, 'enterprise', 'open');

-- Workflow налаштування
INSERT INTO workflow_settings (document_type, workflow_mode, stages) VALUES
('payroll_calculation', 'fast', '["draft","pending_review","pending_approval","approved","posted"]'),
('payment', 'fast', '["draft","pending_approval","approved","paid"]'),
('timesheet', 'simple', '["draft","posted"]');

-- ============================================================================
-- КІНЕЦЬ ТЕСТОВИХ ДАНИХ
-- ============================================================================
