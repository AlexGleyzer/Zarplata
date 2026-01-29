-- ============================================================
-- ПОВНА СХЕМА БД СИСТЕМИ РОЗРАХУНКУ ЗАРПЛАТ
-- Версія: 2.0 (з ієрархіями, TIMESTAMP, immutability)
-- Дата: 2025-01-30
-- ============================================================

-- Розширення PostgreSQL
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- БЛОК 1: ОРГАНІЗАЦІЙНА СТРУКТУРА (ДЕРЕВО ПІДПРИЄМСТВА)
-- ============================================================

CREATE TABLE organizational_units (
    id SERIAL PRIMARY KEY,
    parent_id INTEGER REFERENCES organizational_units(id) ON DELETE SET NULL,
    
    -- Ідентифікація
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Ієрархія
    level INTEGER NOT NULL DEFAULT 1,
    full_path VARCHAR(500),  -- наприклад: "Company/Sales/East"
    
    -- Додаткова інформація
    unit_type VARCHAR(50),  -- company, department, division, team
    cost_center VARCHAR(50),
    location VARCHAR(255),
    responsible_person_id INTEGER,
    
    -- Метадані
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE,
    created_by VARCHAR(100) NOT NULL,
    
    -- Перевірки
    CHECK (id != parent_id),
    CHECK (level > 0)
);

CREATE INDEX idx_org_units_parent ON organizational_units(parent_id);
CREATE INDEX idx_org_units_code ON organizational_units(code);
CREATE INDEX idx_org_units_level ON organizational_units(level);
CREATE INDEX idx_org_units_active ON organizational_units(is_active);

COMMENT ON TABLE organizational_units IS 'Ієрархічна структура підприємства';

-- ============================================================
-- БЛОК 2: ГРУПИ (ДЕРЕВО КАТЕГОРІЙ)
-- ============================================================

CREATE TABLE groups (
    id SERIAL PRIMARY KEY,
    parent_id INTEGER REFERENCES groups(id) ON DELETE SET NULL,
    
    -- Ідентифікація
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Ієрархія
    level INTEGER NOT NULL DEFAULT 1,
    full_path VARCHAR(500),  -- наприклад: "Benefits/Disability/Group2"
    
    -- Тип групи
    group_type VARCHAR(50),  -- social, professional, administrative
    
    -- Метадані
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE,
    
    -- Перевірки
    CHECK (id != parent_id),
    CHECK (level > 0)
);

CREATE INDEX idx_groups_parent ON groups(parent_id);
CREATE INDEX idx_groups_code ON groups(code);
CREATE INDEX idx_groups_level ON groups(level);
CREATE INDEX idx_groups_type ON groups(group_type);

COMMENT ON TABLE groups IS 'Ієрархічна структура груп (пільги, професійні категорії)';

-- ============================================================
-- БЛОК 3: ПРАЦІВНИКИ ТА ПОЗИЦІЇ
-- ============================================================

CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    
    -- Ідентифікація
    personnel_number VARCHAR(50) UNIQUE NOT NULL,
    tax_number VARCHAR(50),
    
    -- ПІБ
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100),
    
    -- Дати
    birth_date DATE,
    hire_date DATE NOT NULL,
    termination_date DATE,
    
    -- Контактна інформація
    email VARCHAR(255),
    phone VARCHAR(50),
    address TEXT,
    
    -- Статус
    status VARCHAR(20) DEFAULT 'active',  -- active, on_leave, terminated
    
    -- Метадані
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE,
    created_by VARCHAR(100) NOT NULL,
    
    -- Перевірки
    CHECK (termination_date IS NULL OR termination_date >= hire_date)
);

CREATE INDEX idx_employees_personnel_number ON employees(personnel_number);
CREATE INDEX idx_employees_tax_number ON employees(tax_number);
CREATE INDEX idx_employees_status ON employees(status);
CREATE INDEX idx_employees_name ON employees(last_name, first_name);

COMMENT ON TABLE employees IS 'Працівники (фізичні особи)';

-- ============================================================

CREATE TABLE positions (
    id SERIAL PRIMARY KEY,
    
    -- Зв'язки
    employee_id INTEGER NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    organizational_unit_id INTEGER NOT NULL REFERENCES organizational_units(id),
    
    -- Ідентифікація позиції
    position_code VARCHAR(50) UNIQUE NOT NULL,
    position_name VARCHAR(255) NOT NULL,
    
    -- Умови роботи
    employment_rate NUMERIC(5, 4) NOT NULL DEFAULT 1.0,  -- 1.0 = 100%, 0.5 = 50%
    
    -- Період дії позиції
    start_date DATE NOT NULL,
    end_date DATE,
    
    -- Статус
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Метадані
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE,
    created_by VARCHAR(100) NOT NULL,
    
    -- Перевірки
    CHECK (employment_rate > 0 AND employment_rate <= 2.0),
    CHECK (end_date IS NULL OR end_date >= start_date)
);

CREATE INDEX idx_positions_employee ON positions(employee_id);
CREATE INDEX idx_positions_org_unit ON positions(organizational_unit_id);
CREATE INDEX idx_positions_dates ON positions(start_date, end_date);
CREATE INDEX idx_positions_active ON positions(is_active);

COMMENT ON TABLE positions IS 'Позиції працівників (може бути кілька позицій у одного працівника)';

-- ============================================================

CREATE TABLE position_groups (
    id SERIAL PRIMARY KEY,
    
    -- Зв'язки
    position_id INTEGER NOT NULL REFERENCES positions(id) ON DELETE CASCADE,
    group_id INTEGER NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    
    -- Період дії належності до групи
    valid_from TIMESTAMP WITH TIME ZONE NOT NULL,
    valid_until TIMESTAMP WITH TIME ZONE,
    
    -- Додаткові параметри групи (кількість дітей, ступінь інвалідності, тощо)
    metadata JSONB,
    
    -- Документи-підстави
    document_number VARCHAR(100),
    document_date DATE,
    
    -- Статус
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL,
    
    -- Перевірки
    CHECK (valid_until IS NULL OR valid_until > valid_from),
    
    -- Унікальність
    UNIQUE(position_id, group_id, valid_from)
);

CREATE INDEX idx_position_groups_position ON position_groups(position_id);
CREATE INDEX idx_position_groups_group ON position_groups(group_id);
CREATE INDEX idx_position_groups_dates ON position_groups(valid_from, valid_until);
CREATE INDEX idx_position_groups_active ON position_groups(is_active);

COMMENT ON TABLE position_groups IS 'Належність позицій до груп (many-to-many з історією)';

-- ============================================================
-- БЛОК 4: КОНТРАКТИ
-- ============================================================

CREATE TABLE contracts (
    id SERIAL PRIMARY KEY,
    
    -- Зв'язок з позицією
    position_id INTEGER NOT NULL REFERENCES positions(id) ON DELETE CASCADE,
    
    -- Тип контракту
    contract_type VARCHAR(20) NOT NULL,  -- salary, hourly, piecework, task_based
    
    -- Умови оплати
    base_rate NUMERIC(12, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'UAH',
    
    -- Період дії
    start_datetime TIMESTAMP WITH TIME ZONE NOT NULL,
    end_datetime TIMESTAMP WITH TIME ZONE,
    
    -- Статус
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Метадані
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE,
    created_by VARCHAR(100) NOT NULL,
    notes TEXT,
    
    -- Перевірки
    CHECK (base_rate >= 0),
    CHECK (end_datetime IS NULL OR end_datetime > start_datetime)
);

CREATE INDEX idx_contracts_position ON contracts(position_id);
CREATE INDEX idx_contracts_dates ON contracts(start_datetime, end_datetime);
CREATE INDEX idx_contracts_active ON contracts(is_active);
CREATE INDEX idx_contracts_type ON contracts(contract_type);

COMMENT ON TABLE contracts IS 'Контракти (умови оплати для позицій)';

-- ============================================================
-- БЛОК 5: ГРАФІКИ РОБОТИ
-- ============================================================

CREATE TABLE shift_schedules (
    id SERIAL PRIMARY KEY,
    
    -- Ідентифікація
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Тип графіку
    schedule_type VARCHAR(20) NOT NULL,  -- fixed, rotating, flexible
    
    -- Налаштування зміни
    shift_start TIME NOT NULL,
    shift_end TIME NOT NULL,
    break_minutes INTEGER DEFAULT 0,
    
    -- Дні роботи (1=Пн, 7=Нд)
    days_of_week INTEGER[],
    
    -- Надбавка за цей графік
    rate_multiplier NUMERIC(5, 2) DEFAULT 1.0,  -- 1.5 для нічних, тощо
    
    -- Статус
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Перевірки
    CHECK (rate_multiplier > 0)
);

CREATE INDEX idx_shift_schedules_code ON shift_schedules(code);
CREATE INDEX idx_shift_schedules_type ON shift_schedules(schedule_type);

COMMENT ON TABLE shift_schedules IS 'Графіки змін (денні, нічні, вечірні)';

-- ============================================================

CREATE TABLE position_schedules (
    id SERIAL PRIMARY KEY,
    
    -- Зв'язки
    position_id INTEGER NOT NULL REFERENCES positions(id) ON DELETE CASCADE,
    schedule_id INTEGER NOT NULL REFERENCES shift_schedules(id),
    
    -- Період дії графіку
    valid_from TIMESTAMP WITH TIME ZONE NOT NULL,
    valid_until TIMESTAMP WITH TIME ZONE,
    
    -- Статус
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Перевірки
    CHECK (valid_until IS NULL OR valid_until > valid_from)
);

CREATE INDEX idx_position_schedules_position ON position_schedules(position_id);
CREATE INDEX idx_position_schedules_schedule ON position_schedules(schedule_id);
CREATE INDEX idx_position_schedules_dates ON position_schedules(valid_from, valid_until);

COMMENT ON TABLE position_schedules IS 'Графіки роботи для позицій';

-- ============================================================
-- БЛОК 6: ТАБЕЛЬ
-- ============================================================

CREATE TABLE timesheets (
    id SERIAL PRIMARY KEY,
    
    -- Зв'язок з позицією
    position_id INTEGER NOT NULL REFERENCES positions(id) ON DELETE CASCADE,
    
    -- Точний час роботи
    work_start TIMESTAMP WITH TIME ZONE NOT NULL,
    work_end TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- Тривалість (автоматично обчислюється)
    duration_minutes INTEGER,
    
    -- Перерви та переробки
    break_minutes INTEGER DEFAULT 0,
    overtime_minutes INTEGER DEFAULT 0,
    
    -- Тип зміни
    shift_type VARCHAR(20),  -- day, night, evening, weekend, holiday
    
    -- Статус
    status VARCHAR(20) DEFAULT 'draft',  -- draft, confirmed, approved
    
    -- Метадані
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE,
    created_by VARCHAR(100) NOT NULL,
    notes TEXT,
    
    -- Перевірки
    CHECK (work_end > work_start),
    CHECK (break_minutes >= 0),
    CHECK (overtime_minutes >= 0)
);

CREATE INDEX idx_timesheets_position ON timesheets(position_id);
CREATE INDEX idx_timesheets_time ON timesheets(work_start, work_end);
CREATE INDEX idx_timesheets_status ON timesheets(status);

COMMENT ON TABLE timesheets IS 'Табель відпрацьованого часу (з точністю до хвилини)';

-- Тригер для автоматичного обчислення duration_minutes
CREATE OR REPLACE FUNCTION calculate_timesheet_duration()
RETURNS TRIGGER AS $$
BEGIN
    NEW.duration_minutes := EXTRACT(EPOCH FROM (NEW.work_end - NEW.work_start)) / 60;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calculate_duration
    BEFORE INSERT OR UPDATE ON timesheets
    FOR EACH ROW
    EXECUTE FUNCTION calculate_timesheet_duration();

-- ============================================================
-- БЛОК 7: ПРАВИЛА РОЗРАХУНКУ (З IMMUTABILITY)
-- ============================================================

CREATE TABLE calculation_rules (
    id SERIAL PRIMARY KEY,
    
    -- Scope (тільки ОДНЕ може бути NOT NULL)
    position_id INTEGER REFERENCES positions(id) ON DELETE CASCADE,
    organizational_unit_id INTEGER REFERENCES organizational_units(id) ON DELETE CASCADE,
    group_id INTEGER REFERENCES groups(id) ON DELETE CASCADE,
    -- Якщо всі NULL = глобальне правило
    
    -- Ідентифікація правила
    code VARCHAR(50) NOT NULL,  -- НЕ унікальний! можуть бути версії
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Логіка розрахунку
    sql_code TEXT NOT NULL,
    rule_type VARCHAR(20) NOT NULL,  -- accrual, deduction, tax, benefit
    
    -- Логіка застосування
    combination_mode VARCHAR(20) DEFAULT 'CUMULATIVE',
    -- CUMULATIVE, EXCLUSIVE, PRIORITY, MAX_BENEFIT, OVERRIDE, SUPPLEMENT
    
    priority INTEGER DEFAULT 0,
    
    -- Період дії правила (IMMUTABILITY!)
    valid_from TIMESTAMP WITH TIME ZONE NOT NULL,
    valid_until TIMESTAMP WITH TIME ZONE,
    
    -- Версійність
    version INTEGER DEFAULT 1,
    replaces_rule_id INTEGER REFERENCES calculation_rules(id) ON DELETE SET NULL,
    
    -- Часові обмеження правила
    time_of_day_start TIME,  -- працює тільки з цього часу
    time_of_day_end TIME,    -- до цього часу
    days_of_week INTEGER[],  -- працює тільки в ці дні тижня
    
    -- Обмеження
    exclusion_groups JSONB,  -- несумісні групи
    max_combined_amount NUMERIC(12, 2),
    metadata JSONB,
    
    -- Статус
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE,
    created_by VARCHAR(100) NOT NULL,
    notes TEXT,
    legal_basis TEXT,  -- посилання на закон/наказ
    
    -- Перевірки
    CHECK (valid_until IS NULL OR valid_until > valid_from),
    CHECK (
        (position_id IS NOT NULL AND organizational_unit_id IS NULL AND group_id IS NULL) OR
        (position_id IS NULL AND organizational_unit_id IS NOT NULL AND group_id IS NULL) OR
        (position_id IS NULL AND organizational_unit_id IS NULL AND group_id IS NOT NULL) OR
        (position_id IS NULL AND organizational_unit_id IS NULL AND group_id IS NULL)
    )
);

CREATE INDEX idx_rules_code ON calculation_rules(code);
CREATE INDEX idx_rules_position ON calculation_rules(position_id);
CREATE INDEX idx_rules_org_unit ON calculation_rules(organizational_unit_id);
CREATE INDEX idx_rules_group ON calculation_rules(group_id);
CREATE INDEX idx_rules_dates ON calculation_rules(valid_from, valid_until);
CREATE INDEX idx_rules_code_dates ON calculation_rules(code, valid_from, valid_until);
CREATE INDEX idx_rules_replaces ON calculation_rules(replaces_rule_id);
CREATE INDEX idx_rules_active ON calculation_rules(is_active);

COMMENT ON TABLE calculation_rules IS 'Правила розрахунку (immutable, з версійністю)';

-- ============================================================
-- БЛОК 8: ШАБЛОНИ РОЗРАХУНКУ
-- ============================================================

CREATE TABLE calculation_templates (
    id SERIAL PRIMARY KEY,
    
    -- Ідентифікація
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Тип шаблону
    template_type VARCHAR(50),  -- monthly_salary, hourly_pay, bonus, etc.
    
    -- Статус
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE,
    created_by VARCHAR(100) NOT NULL
);

CREATE INDEX idx_templates_code ON calculation_templates(code);
CREATE INDEX idx_templates_type ON calculation_templates(template_type);

COMMENT ON TABLE calculation_templates IS 'Шаблони розрахунків (набір правил в послідовності)';

-- ============================================================

CREATE TABLE template_rules (
    id SERIAL PRIMARY KEY,
    
    -- Зв'язки
    template_id INTEGER NOT NULL REFERENCES calculation_templates(id) ON DELETE CASCADE,
    rule_code VARCHAR(50) NOT NULL,  -- НЕ FK, бо правило може змінитись!
    
    -- Порядок виконання
    execution_order INTEGER NOT NULL,
    
    -- Умовне виконання (опціонально)
    condition_sql TEXT,
    
    -- Метадані
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Унікальність
    UNIQUE(template_id, rule_code),
    UNIQUE(template_id, execution_order)
);

CREATE INDEX idx_template_rules_template ON template_rules(template_id);
CREATE INDEX idx_template_rules_order ON template_rules(template_id, execution_order);

COMMENT ON TABLE template_rules IS 'Правила в шаблонах (з порядком виконання)';

-- ============================================================
-- БЛОК 9: ПЕРІОДИ РОЗРАХУНКУ (З АВТОМАТИЧНИМ РОЗБИТТЯМ)
-- ============================================================

CREATE TABLE calculation_periods (
    id SERIAL PRIMARY KEY,
    
    -- Ідентифікація періоду
    period_code VARCHAR(50) NOT NULL,  -- "2024-01", "2024-01-1", "2024-01-2"
    period_name VARCHAR(255) NOT NULL,
    
    -- Точний час періоду
    start_datetime TIMESTAMP WITH TIME ZONE NOT NULL,
    end_datetime TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- Тип періоду
    period_type VARCHAR(20) NOT NULL,  -- monthly, weekly, hourly, custom, split
    
    -- Scope
    organizational_unit_id INTEGER REFERENCES organizational_units(id),
    employee_id INTEGER REFERENCES employees(id),
    
    -- Розбиття періоду
    split_reason VARCHAR(50),  -- rate_change, rule_change, group_change, schedule_change
    parent_period_id INTEGER REFERENCES calculation_periods(id) ON DELETE SET NULL,
    
    -- Snapshot умов (для immutability)
    conditions_snapshot JSONB,
    
    -- Статус
    status VARCHAR(20) DEFAULT 'draft',  -- draft, in_calculation, completed, approved
    
    -- Метадані
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE,
    created_by VARCHAR(100) NOT NULL,
    notes TEXT,
    
    -- Перевірки
    CHECK (end_datetime > start_datetime)
);

CREATE INDEX idx_periods_code ON calculation_periods(period_code);
CREATE INDEX idx_periods_dates ON calculation_periods(start_datetime, end_datetime);
CREATE INDEX idx_periods_org_unit ON calculation_periods(organizational_unit_id);
CREATE INDEX idx_periods_employee ON calculation_periods(employee_id);
CREATE INDEX idx_periods_parent ON calculation_periods(parent_period_id);
CREATE INDEX idx_periods_status ON calculation_periods(status);

COMMENT ON TABLE calculation_periods IS 'Періоди розрахунку (з автоматичним розбиттям при змінах)';

-- ============================================================
-- БЛОК 10: ДОКУМЕНТИ НАРАХУВАНЬ
-- ============================================================

CREATE TABLE accrual_documents (
    id SERIAL PRIMARY KEY,
    
    -- Ідентифікація документа
    document_number VARCHAR(50) UNIQUE NOT NULL,
    document_date DATE NOT NULL,
    
    -- Зв'язки
    period_id INTEGER NOT NULL REFERENCES calculation_periods(id),
    template_id INTEGER NOT NULL REFERENCES calculation_templates(id),
    organizational_unit_id INTEGER REFERENCES organizational_units(id),
    
    -- Статус документа
    status VARCHAR(20) DEFAULT 'draft',  -- draft, calculated, in_review, approved, cancelled
    
    -- Workflow
    calculated_at TIMESTAMP WITH TIME ZONE,
    calculated_by VARCHAR(100),
    approved_at TIMESTAMP WITH TIME ZONE,
    approved_by VARCHAR(100),
    
    -- Метадані
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE,
    created_by VARCHAR(100) NOT NULL,
    notes TEXT
);

CREATE INDEX idx_accrual_docs_number ON accrual_documents(document_number);
CREATE INDEX idx_accrual_docs_period ON accrual_documents(period_id);
CREATE INDEX idx_accrual_docs_template ON accrual_documents(template_id);
CREATE INDEX idx_accrual_docs_status ON accrual_documents(status);
CREATE INDEX idx_accrual_docs_date ON accrual_documents(document_date);

COMMENT ON TABLE accrual_documents IS 'Документи нарахувань';

-- ============================================================

CREATE TABLE accrual_results (
    id SERIAL PRIMARY KEY,
    
    -- Зв'язки
    document_id INTEGER NOT NULL REFERENCES accrual_documents(id) ON DELETE CASCADE,
    position_id INTEGER NOT NULL REFERENCES positions(id),
    employee_id INTEGER NOT NULL REFERENCES employees(id),  -- денормалізація
    organizational_unit_id INTEGER NOT NULL REFERENCES organizational_units(id),  -- денормалізація
    
    -- Правило що застосовано
    rule_id INTEGER NOT NULL REFERENCES calculation_rules(id),
    rule_code VARCHAR(50) NOT NULL,  -- копія для історії
    
    -- Джерело правила (для аудиту)
    rule_source_type VARCHAR(20),  -- position, group, organizational_unit, global
    rule_source_id INTEGER,  -- ID джерела
    
    -- Результат розрахунку
    amount NUMERIC(12, 2) NOT NULL,
    calculation_base NUMERIC(12, 2),  -- база розрахунку (якщо є)
    currency VARCHAR(3) DEFAULT 'UAH',
    
    -- Статус
    status VARCHAR(20) DEFAULT 'active',  -- active, cancelled, corrected
    
    -- Метадані
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    notes TEXT
);

CREATE INDEX idx_accrual_results_document ON accrual_results(document_id);
CREATE INDEX idx_accrual_results_position ON accrual_results(position_id);
CREATE INDEX idx_accrual_results_employee ON accrual_results(employee_id);
CREATE INDEX idx_accrual_results_org_unit ON accrual_results(organizational_unit_id);
CREATE INDEX idx_accrual_results_rule ON accrual_results(rule_id);
CREATE INDEX idx_accrual_results_rule_code ON accrual_results(rule_code);
CREATE INDEX idx_accrual_results_status ON accrual_results(status);

COMMENT ON TABLE accrual_results IS 'Результати нарахувань (деталі по кожному правилу)';

-- ============================================================
-- БЛОК 11: МАТЕРІАЛІЗОВАНЕ ПРЕДСТАВЛЕННЯ ДЛЯ ПЕРЕГЛЯДУ
-- ============================================================

CREATE MATERIALIZED VIEW accrual_summary AS
SELECT 
    -- Документ
    ad.id as document_id,
    ad.document_number,
    ad.document_date,
    ad.status as document_status,
    
    -- Період
    cp.id as period_id,
    cp.period_code,
    cp.period_name,
    cp.start_datetime,
    cp.end_datetime,
    cp.period_type,
    cp.split_reason,
    cp.parent_period_id,
    
    -- Шаблон
    ct.id as template_id,
    ct.code as template_code,
    ct.name as template_name,
    
    -- Працівник
    e.id as employee_id,
    e.personnel_number,
    e.first_name,
    e.last_name,
    e.first_name || ' ' || e.last_name as employee_name,
    
    -- Позиція
    p.id as position_id,
    p.position_code,
    p.position_name,
    p.employment_rate,
    
    -- Підрозділ
    ou.id as org_unit_id,
    ou.code as org_unit_code,
    ou.name as org_unit_name,
    ou.level as org_unit_level,
    
    -- Правило
    ar.rule_id,
    ar.rule_code,
    cr.name as rule_name,
    cr.rule_type,
    cr.combination_mode,
    
    -- Джерело правила
    ar.rule_source_type,
    ar.rule_source_id,
    CASE 
        WHEN ar.rule_source_type = 'position' THEN 'Позиція: ' || p.position_name
        WHEN ar.rule_source_type = 'group' THEN 'Група: ' || g.name
        WHEN ar.rule_source_type = 'organizational_unit' THEN 'Підрозділ: ' || ou.name
        ELSE 'Глобальне правило'
    END as rule_source_description,
    
    -- Результат
    ar.amount,
    ar.calculation_base,
    ar.currency,
    ar.status as result_status,
    
    -- Метадані
    ar.created_at as calculated_at,
    ad.approved_at,
    ad.approved_by
    
FROM accrual_documents ad
JOIN calculation_periods cp ON cp.id = ad.period_id
JOIN calculation_templates ct ON ct.id = ad.template_id
JOIN accrual_results ar ON ar.document_id = ad.id
JOIN positions p ON p.id = ar.position_id
JOIN employees e ON e.id = ar.employee_id
JOIN organizational_units ou ON ou.id = ar.organizational_unit_id
JOIN calculation_rules cr ON cr.id = ar.rule_id
LEFT JOIN groups g ON g.id = ar.rule_source_id AND ar.rule_source_type = 'group'

WHERE ar.status = 'active'

ORDER BY 
    ad.document_date DESC,
    e.personnel_number,
    ar.created_at;

-- Індекси для швидкого пошуку
CREATE INDEX idx_accrual_summary_document ON accrual_summary(document_id);
CREATE INDEX idx_accrual_summary_period ON accrual_summary(period_id);
CREATE INDEX idx_accrual_summary_employee ON accrual_summary(employee_id);
CREATE INDEX idx_accrual_summary_org_unit ON accrual_summary(org_unit_id);
CREATE INDEX idx_accrual_summary_rule ON accrual_summary(rule_code);
CREATE INDEX idx_accrual_summary_dates ON accrual_summary(start_datetime, end_datetime);

COMMENT ON MATERIALIZED VIEW accrual_summary IS 'Зведена таблиця нарахувань для швидкого перегляду';

-- Функція для оновлення матеріалізованого представлення
CREATE OR REPLACE FUNCTION refresh_accrual_summary()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY accrual_summary;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- БЛОК 12: ДОВІДНИКИ
-- ============================================================

CREATE TABLE split_reasons (
    code VARCHAR(50) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    auto_split BOOLEAN DEFAULT TRUE,  -- чи розбивати автоматично
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

INSERT INTO split_reasons (code, name, description, auto_split) VALUES
('RATE_CHANGE', 'Зміна ставки', 'Змінилась employment_rate позиції', true),
('CONTRACT_RATE_CHANGE', 'Зміна окладу', 'Змінилась base_rate в контракті', true),
('CONTRACT_TYPE_CHANGE', 'Зміна типу контракту', 'Зміна salary → hourly тощо', true),
('GROUP_ADDED', 'Додана група', 'Позиція додана до нової групи', true),
('GROUP_REMOVED', 'Видалена група', 'Позиція видалена з групи', true),
('GROUP_METADATA_CHANGE', 'Зміна даних групи', 'Змінились діти, інвалідність тощо', true),
('RULE_CHANGED', 'Зміна правила', 'Створена нова версія правила', true),
('RULE_ADDED', 'Додане правило', 'Створене нове правило що перевизначає', true),
('TAX_RATE_CHANGE', 'Зміна ставки податку', 'Законодавчі зміни', true),
('SCHEDULE_CHANGE', 'Зміна графіку', 'Зміна денної/нічної зміни', true),
('SHIFT_TRANSITION', 'Перехід між змінами', 'Автоматичний перехід (22:00, 06:00)', true),
('MIDNIGHT_SPLIT', 'Перехід через опівніч', 'Автоматичне розбиття при 00:00', true),
('ORGANIZATIONAL_CHANGE', 'Переведення', 'Зміна підрозділу (нова позиція)', false),
('MANUAL_SPLIT', 'Ручне розбиття', 'Оператор вручну розбив період', false);

COMMENT ON TABLE split_reasons IS 'Довідник причин розбиття періодів';

-- ============================================================
-- КІНЕЦЬ СХЕМИ
-- ============================================================