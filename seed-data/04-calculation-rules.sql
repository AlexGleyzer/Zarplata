-- ============================================================
-- ПРАВИЛА РОЗРАХУНКУ: 4-рівнева ієрархія
-- ============================================================

TRUNCATE calculation_rules RESTART IDENTITY CASCADE;

-- ============================================================
-- РІВЕНЬ 4: ГЛОБАЛЬНІ ПРАВИЛА (для всіх)
-- ============================================================

-- ПДФО (Податок на доходи фізичних осіб) - базовий 18%
INSERT INTO calculation_rules (
    position_id, organizational_unit_id, group_id,
    code, name, sql_code, rule_type,
    valid_from, created_by
) VALUES (
    NULL, NULL, NULL,
    'PIT', 'ПДФО (базовий)', 
    'base_salary * 0.18', 'tax',
    '2024-01-01 00:00:00+00', 'seed_data'
);

-- Військовий збір - 1.5%
INSERT INTO calculation_rules (
    position_id, organizational_unit_id, group_id,
    code, name, sql_code, rule_type,
    valid_from, created_by
) VALUES (
    NULL, NULL, NULL,
    'MIL_TAX', 'Військовий збір', 
    'base_salary * 0.015', 'tax',
    '2024-01-01 00:00:00+00', 'seed_data'
);

-- ЄСВ (Єдиний соціальний внесок) - 22%
INSERT INTO calculation_rules (
    position_id, organizational_unit_id, group_id,
    code, name, sql_code, rule_type,
    valid_from, created_by
) VALUES (
    NULL, NULL, NULL,
    'ESV', 'ЄСВ', 
    'base_salary * 0.22', 'deduction',
    '2024-01-01 00:00:00+00', 'seed_data'
);

-- ============================================================
-- РІВЕНЬ 3: ПРАВИЛА ДЛЯ ПІДРОЗДІЛІВ
-- ============================================================

-- Бонус для IT підрозділу (org_unit_id = 9)
INSERT INTO calculation_rules (
    position_id, organizational_unit_id, group_id,
    code, name, sql_code, rule_type,
    valid_from, created_by
) VALUES (
    NULL, 33, NULL,
    'IT_BONUS', 'IT бонус', 
    'base_salary * 0.15', 'accrual',
    '2024-01-01 00:00:00+00', 'seed_data'
);

-- ============================================================
-- РІВЕНЬ 2: ПРАВИЛА ДЛЯ ГРУП (ПІЛЬГИ!)
-- ============================================================

-- Інваліди 2 групи (group_id = 101) - ПДФО зі знижкою 50%
INSERT INTO calculation_rules (
    position_id, organizational_unit_id, group_id,
    code, name, sql_code, rule_type,
    valid_from, created_by
) VALUES (
    NULL, NULL, 101,
    'PIT', 'ПДФО (інваліди 2 гр.)', 
    'base_salary * 0.09', 'tax',  -- 9% замість 18%
    '2024-01-01 00:00:00+00', 'seed_data'
);

-- Багатодітні сім'ї (group_id = 110) - ПДФО зі знижкою 30%
INSERT INTO calculation_rules (
    position_id, organizational_unit_id, group_id,
    code, name, sql_code, rule_type,
    valid_from, created_by
) VALUES (
    NULL, NULL, 110,
    'PIT', 'ПДФО (багатодітні)', 
    'base_salary * 0.126', 'tax',  -- 12.6% замість 18%
    '2024-01-01 00:00:00+00', 'seed_data'
);

-- Ветерани АТО (group_id = 121) - ПДФО пільга 100% (звільнення!)
INSERT INTO calculation_rules (
    position_id, organizational_unit_id, group_id,
    code, name, sql_code, rule_type,
    valid_from, created_by
) VALUES (
    NULL, NULL, 121,
    'PIT', 'ПДФО (ветерани АТО)', 
    '0', 'tax',  -- 0% - повне звільнення
    '2024-01-01 00:00:00+00', 'seed_data'
);

-- Матері-одиначки (group_id = 111) - соціальна допомога 1000 грн
INSERT INTO calculation_rules (
    position_id, organizational_unit_id, group_id,
    code, name, sql_code, rule_type,
    valid_from, created_by
) VALUES (
    NULL, NULL, 111,
    'SOCIAL_BENEFIT', 'Соціальна допомога (матері-одиначки)', 
    '1000', 'benefit',
    '2024-01-01 00:00:00+00', 'seed_data'
);

-- Класні керівники (group_id = 200) - доплата 500 грн
INSERT INTO calculation_rules (
    position_id, organizational_unit_id, group_id,
    code, name, sql_code, rule_type,
    valid_from, created_by
) VALUES (
    NULL, NULL, 200,
    'CLASS_BONUS', 'Доплата за класне керівництво', 
    '500', 'accrual',
    '2024-01-01 00:00:00+00', 'seed_data'
);

-- Молоді спеціалісти (group_id = 204) - надбавка 10%
INSERT INTO calculation_rules (
    position_id, organizational_unit_id, group_id,
    code, name, sql_code, rule_type,
    valid_from, created_by
) VALUES (
    NULL, NULL, 204,
    'YOUNG_BONUS', 'Надбавка молодим спеціалістам', 
    'base_salary * 0.10', 'accrual',
    '2024-01-01 00:00:00+00', 'seed_data'
);

-- Члени профспілки (group_id = 300) - профспілкові внески 1%
INSERT INTO calculation_rules (
    position_id, organizational_unit_id, group_id,
    code, name, sql_code, rule_type,
    valid_from, created_by
) VALUES (
    NULL, NULL, 300,
    'UNION_FEE', 'Профспілкові внески', 
    'base_salary * 0.01', 'deduction',
    '2024-01-01 00:00:00+00', 'seed_data'
);