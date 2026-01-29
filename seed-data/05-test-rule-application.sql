-- ============================================================
-- ТЕСТ: Застосування Правил за 4-Рівневою Ієрархією
-- ============================================================

-- Для кожного працівника знайти яке правило ПДВ застосується
WITH rule_hierarchy AS (
    SELECT 
        p.id as position_id,
        e.personnel_number,
        e.first_name || ' ' || e.last_name as employee_name,
        
        -- Рівень 1: Персональне правило
        (SELECT cr.id FROM calculation_rules cr 
         WHERE cr.position_id = p.id 
           AND cr.code = 'PIT' 
           AND cr.is_active = true
         LIMIT 1) as position_rule_id,
        
        -- Рівень 2: Правило групи (беремо найбільш специфічне)
        (SELECT cr.id FROM calculation_rules cr 
         JOIN position_groups pg ON pg.group_id = cr.group_id
         WHERE pg.position_id = p.id 
           AND cr.code = 'PIT'
           AND cr.is_active = true
           AND pg.is_active = true
         ORDER BY pg.group_id DESC  -- більший ID = більш специфічна група
         LIMIT 1) as group_rule_id,
        
        -- Рівень 3: Правило підрозділу
        (SELECT cr.id FROM calculation_rules cr 
         WHERE cr.organizational_unit_id = p.organizational_unit_id
           AND cr.code = 'PIT'
           AND cr.is_active = true
         LIMIT 1) as org_unit_rule_id,
        
        -- Рівень 4: Глобальне правило
        (SELECT cr.id FROM calculation_rules cr 
         WHERE cr.position_id IS NULL 
           AND cr.organizational_unit_id IS NULL
           AND cr.group_id IS NULL
           AND cr.code = 'PIT'
           AND cr.is_active = true
         LIMIT 1) as global_rule_id
        
    FROM positions p
    JOIN employees e ON e.id = p.employee_id
    WHERE p.is_active = true
)
SELECT 
    rh.personnel_number,
    rh.employee_name,
    
    -- Який рівень застосується
    CASE 
        WHEN rh.position_rule_id IS NOT NULL THEN '🎯 POSITION'
        WHEN rh.group_rule_id IS NOT NULL THEN '🏷️ GROUP'
        WHEN rh.org_unit_rule_id IS NOT NULL THEN '🏢 ORG_UNIT'
        ELSE '🌍 GLOBAL'
    END as applied_level,
    
    -- Яке правило
    COALESCE(
        (SELECT cr.name FROM calculation_rules cr WHERE cr.id = rh.position_rule_id),
        (SELECT cr.name FROM calculation_rules cr WHERE cr.id = rh.group_rule_id),
        (SELECT cr.name FROM calculation_rules cr WHERE cr.id = rh.org_unit_rule_id),
        (SELECT cr.name FROM calculation_rules cr WHERE cr.id = rh.global_rule_id)
    ) as rule_name,
    
    -- SQL код правила
    COALESCE(
        (SELECT cr.sql_code FROM calculation_rules cr WHERE cr.id = rh.position_rule_id),
        (SELECT cr.sql_code FROM calculation_rules cr WHERE cr.id = rh.group_rule_id),
        (SELECT cr.sql_code FROM calculation_rules cr WHERE cr.id = rh.org_unit_rule_id),
        (SELECT cr.sql_code FROM calculation_rules cr WHERE cr.id = rh.global_rule_id)
    ) as rule_formula,
    
    -- Для наочності - в яких групах
    (SELECT string_agg(g.name, ', ')
     FROM position_groups pg
     JOIN groups g ON g.id = pg.group_id
     WHERE pg.position_id = rh.position_id
       AND pg.is_active = true
    ) as groups
    
FROM rule_hierarchy rh
ORDER BY 
    CASE 
        WHEN rh.position_rule_id IS NOT NULL THEN 1
        WHEN rh.group_rule_id IS NOT NULL THEN 2
        WHEN rh.org_unit_rule_id IS NOT NULL THEN 3
        ELSE 4
    END,
    rh.personnel_number;

-- Додатково: Всі правила що застосуються до кожного працівника
SELECT 
    e.personnel_number,
    e.first_name || ' ' || e.last_name as employee_name,
    cr.code as rule_code,
    cr.name as rule_name,
    cr.rule_type,
    cr.sql_code,
    CASE 
        WHEN cr.position_id IS NOT NULL THEN '1-POSITION'
        WHEN cr.group_id IS NOT NULL THEN '2-GROUP'
        WHEN cr.organizational_unit_id IS NOT NULL THEN '3-ORG_UNIT'
        ELSE '4-GLOBAL'
    END as rule_level
FROM positions p
JOIN employees e ON e.id = p.employee_id
LEFT JOIN position_groups pg ON pg.position_id = p.id AND pg.is_active = true
LEFT JOIN calculation_rules cr ON (
    cr.position_id = p.id OR
    cr.group_id = pg.group_id OR
    cr.organizational_unit_id = p.organizational_unit_id OR
    (cr.position_id IS NULL AND cr.group_id IS NULL AND cr.organizational_unit_id IS NULL)
)
WHERE p.is_active = true
  AND cr.is_active = true
ORDER BY e.personnel_number, rule_level, cr.code;