"""add_groups_hierarchy_and_timestamps

Revision ID: 002_groups_hierarchy
Revises: 001_initial_schema
Create Date: 2025-01-30 16:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers
revision = '002_20260129120709_add_groups_hierarchy'
down_revision = '001_seed_data'  # ВАЖЛИВО: змінити на ID твоєї першої міграції!
branch_labels = None
depends_on = None


def upgrade():
    """
    Міграція на версію 2.0:
    - Дерево груп (parent_id)
    - TIMESTAMP замість DATE
    - position_groups (many-to-many)
    - shift_schedules
    - Immutability правил
    - Materialized view для перегляду
    """
    
    # ========== 1. GROUPS - Додати parent_id для ієрархії ==========
    print("Adding parent_id to groups...")
    
    op.add_column('groups', 
        sa.Column('parent_id', sa.Integer(), nullable=True)
    )
    op.add_column('groups',
        sa.Column('level', sa.Integer(), nullable=False, server_default='1')
    )
    op.add_column('groups',
        sa.Column('full_path', sa.String(500), nullable=True)
    )
    
    op.create_foreign_key(
        'fk_groups_parent',
        'groups', 'groups',
        ['parent_id'], ['id'],
        ondelete='SET NULL'
    )
    
    op.create_index('idx_groups_parent', 'groups', ['parent_id'])
    op.create_index('idx_groups_level', 'groups', ['level'])
    
    # ========== 2. POSITION_GROUPS - Many-to-Many ==========
    print("Creating position_groups table...")
    
    op.create_table(
        'position_groups',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('position_id', sa.Integer(), nullable=False),
        sa.Column('group_id', sa.Integer(), nullable=False),
        
        # Період дії
        sa.Column('valid_from', sa.TIMESTAMP(timezone=True), nullable=False),
        sa.Column('valid_until', sa.TIMESTAMP(timezone=True), nullable=True),
        
        # Додаткові дані
        sa.Column('metadata', postgresql.JSONB(), nullable=True),
        
        # Документи-підстави
        sa.Column('document_number', sa.String(100), nullable=True),
        sa.Column('document_date', sa.Date(), nullable=True),
        
        sa.Column('is_active', sa.Boolean(), default=True),
        sa.Column('created_at', sa.TIMESTAMP(timezone=True), server_default=sa.text('NOW()')),
        sa.Column('created_by', sa.String(100), nullable=False, server_default='system'),
        
        sa.ForeignKeyConstraint(['position_id'], ['positions.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['group_id'], ['groups.id'], ondelete='CASCADE'),
        
        sa.UniqueConstraint('position_id', 'group_id', 'valid_from', name='uq_position_group_date')
    )
    
    op.create_index('idx_position_groups_position', 'position_groups', ['position_id'])
    op.create_index('idx_position_groups_group', 'position_groups', ['group_id'])
    op.create_index('idx_position_groups_dates', 'position_groups', ['valid_from', 'valid_until'])
    
    # ========== 3. SHIFT_SCHEDULES - Графіки змін ==========
    print("Creating shift_schedules table...")
    
    op.create_table(
        'shift_schedules',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('code', sa.String(50), unique=True, nullable=False),
        sa.Column('name', sa.String(255), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        
        # Тип графіку
        sa.Column('schedule_type', sa.String(20), nullable=False),
        
        # Налаштування зміни
        sa.Column('shift_start', sa.Time(), nullable=False),
        sa.Column('shift_end', sa.Time(), nullable=False),
        sa.Column('break_minutes', sa.Integer(), default=0),
        
        # Дні роботи
        sa.Column('days_of_week', postgresql.ARRAY(sa.Integer()), nullable=True),
        
        # Надбавка
        sa.Column('rate_multiplier', sa.Numeric(5, 2), default=1.0),
        
        sa.Column('is_active', sa.Boolean(), default=True),
        sa.Column('created_at', sa.TIMESTAMP(timezone=True), server_default=sa.text('NOW()'))
    )
    
    op.create_index('idx_shift_schedules_code', 'shift_schedules', ['code'])
    
    # ========== 4. POSITION_SCHEDULES ==========
    print("Creating position_schedules table...")
    
    op.create_table(
        'position_schedules',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('position_id', sa.Integer(), nullable=False),
        sa.Column('schedule_id', sa.Integer(), nullable=False),
        
        sa.Column('valid_from', sa.TIMESTAMP(timezone=True), nullable=False),
        sa.Column('valid_until', sa.TIMESTAMP(timezone=True), nullable=True),
        
        sa.Column('is_active', sa.Boolean(), default=True),
        sa.Column('created_at', sa.TIMESTAMP(timezone=True), server_default=sa.text('NOW()')),
        
        sa.ForeignKeyConstraint(['position_id'], ['positions.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['schedule_id'], ['shift_schedules.id'], ondelete='CASCADE')
    )
    
    op.create_index('idx_position_schedules_position', 'position_schedules', ['position_id'])
    op.create_index('idx_position_schedules_dates', 'position_schedules', ['valid_from', 'valid_until'])
    
    # ========== 5. CALCULATION_RULES - Оновлення ==========
    print("Updating calculation_rules...")
    
    # Додати group_id
    op.add_column('calculation_rules',
        sa.Column('group_id', sa.Integer(), nullable=True)
    )
    op.create_foreign_key(
        'fk_rules_group',
        'calculation_rules', 'groups',
        ['group_id'], ['id'],
        ondelete='SET NULL'
    )
    
    # Часові поля
    op.add_column('calculation_rules',
        sa.Column('time_of_day_start', sa.Time(), nullable=True)
    )
    op.add_column('calculation_rules',
        sa.Column('time_of_day_end', sa.Time(), nullable=True)
    )
    op.add_column('calculation_rules',
        sa.Column('days_of_week', postgresql.ARRAY(sa.Integer()), nullable=True)
    )
    
    # Версійність
    op.add_column('calculation_rules',
        sa.Column('version', sa.Integer(), default=1, server_default='1')
    )
    op.add_column('calculation_rules',
        sa.Column('replaces_rule_id', sa.Integer(), nullable=True)
    )
    op.create_foreign_key(
        'fk_rules_replaces',
        'calculation_rules', 'calculation_rules',
        ['replaces_rule_id'], ['id'],
        ondelete='SET NULL'
    )
    
    # Комбінація правил
    op.add_column('calculation_rules',
        sa.Column('combination_mode', sa.String(20), default='CUMULATIVE', server_default='CUMULATIVE')
    )
    op.add_column('calculation_rules',
        sa.Column('priority', sa.Integer(), default=0, server_default='0')
    )
    op.add_column('calculation_rules',
        sa.Column('exclusion_groups', postgresql.JSONB(), nullable=True)
    )
    op.add_column('calculation_rules',
        sa.Column('max_combined_amount', sa.Numeric(12, 2), nullable=True)
    )
    
    # DATE → TIMESTAMP для valid_from/until
    print("Converting DATE to TIMESTAMP in calculation_rules...")
    
    # Перевіряємо чи існують колонки valid_from/valid_until
    connection = op.get_bind()
    inspector = sa.inspect(connection)
    columns = [col['name'] for col in inspector.get_columns('calculation_rules')]
    
    if 'valid_from' in columns:
        # Додаємо тимчасові колонки
        op.add_column('calculation_rules',
            sa.Column('valid_from_ts', sa.TIMESTAMP(timezone=True), nullable=True)
        )
        op.add_column('calculation_rules',
            sa.Column('valid_until_ts', sa.TIMESTAMP(timezone=True), nullable=True)
        )
        
        # Копіюємо дані
        op.execute("""
            UPDATE calculation_rules 
            SET valid_from_ts = valid_from::timestamp with time zone
            WHERE valid_from IS NOT NULL
        """)
        op.execute("""
            UPDATE calculation_rules 
            SET valid_until_ts = valid_until::timestamp with time zone
            WHERE valid_until IS NOT NULL
        """)
        
        # Видаляємо старі
        op.drop_column('calculation_rules', 'valid_from')
        op.drop_column('calculation_rules', 'valid_until')
        
        # Перейменовуємо
        op.alter_column('calculation_rules', 'valid_from_ts', new_column_name='valid_from')
        op.alter_column('calculation_rules', 'valid_until_ts', new_column_name='valid_until')
    else:
        # Якщо колонок немає - просто додаємо нові
        op.add_column('calculation_rules',
            sa.Column('valid_from', sa.TIMESTAMP(timezone=True), nullable=False, 
                     server_default=sa.text('NOW()'))
        )
        op.add_column('calculation_rules',
            sa.Column('valid_until', sa.TIMESTAMP(timezone=True), nullable=True)
        )
    
    # Індекси
    op.create_index('idx_rules_group_dates', 'calculation_rules', 
                    ['group_id', 'valid_from', 'valid_until'])
    op.create_index('idx_rules_replaces', 'calculation_rules', ['replaces_rule_id'])
    op.create_index('idx_rules_code_dates', 'calculation_rules',
                    ['code', 'valid_from', 'valid_until'])
    
    # ========== 6. CALCULATION_PERIODS - TIMESTAMP ==========
    print("Converting calculation_periods to TIMESTAMP...")
    
    # Перевіряємо структуру
    columns = [col['name'] for col in inspector.get_columns('calculation_periods')]
    
    if 'start_date' in columns:
        # Додаємо нові колонки
        op.add_column('calculation_periods',
            sa.Column('start_datetime', sa.TIMESTAMP(timezone=True), nullable=True)
        )
        op.add_column('calculation_periods',
            sa.Column('end_datetime', sa.TIMESTAMP(timezone=True), nullable=True)
        )
        
        # Копіюємо дані (end_date стає 23:59:59 того дня)
        op.execute("""
            UPDATE calculation_periods 
            SET start_datetime = start_date::timestamp with time zone,
                end_datetime = (end_date::timestamp + interval '23 hours 59 minutes 59 seconds') at time zone 'UTC'
            WHERE start_date IS NOT NULL
        """)
        
        # Видаляємо старі
        op.drop_column('calculation_periods', 'start_date')
        op.drop_column('calculation_periods', 'end_date')
        
        # NOT NULL для нових
        op.alter_column('calculation_periods', 'start_datetime', nullable=False)
        op.alter_column('calculation_periods', 'end_datetime', nullable=False)
    
    # Додати поля для розбиття
    op.add_column('calculation_periods',
        sa.Column('split_reason', sa.String(50), nullable=True)
    )
    op.add_column('calculation_periods',
        sa.Column('parent_period_id', sa.Integer(), nullable=True)
    )
    op.add_column('calculation_periods',
        sa.Column('conditions_snapshot', postgresql.JSONB(), nullable=True)
    )
    
    op.create_foreign_key(
        'fk_periods_parent',
        'calculation_periods', 'calculation_periods',
        ['parent_period_id'], ['id'],
        ondelete='SET NULL'
    )
    
    op.create_index('idx_periods_parent', 'calculation_periods', ['parent_period_id'])
    op.create_index('idx_periods_datetime', 'calculation_periods', 
                    ['start_datetime', 'end_datetime'])
    
    # ========== 7. TIMESHEETS - TIMESTAMP ==========
    print("Converting timesheets to TIMESTAMP...")
    
    columns = [col['name'] for col in inspector.get_columns('timesheets')]
    
    if 'work_date' in columns:
        # Додаємо нові колонки
        op.add_column('timesheets',
            sa.Column('work_start', sa.TIMESTAMP(timezone=True), nullable=True)
        )
        op.add_column('timesheets',
            sa.Column('work_end', sa.TIMESTAMP(timezone=True), nullable=True)
        )
        op.add_column('timesheets',
            sa.Column('duration_minutes', sa.Integer(), nullable=True)
        )
        
        # Копіюємо дані (припускаємо початок роботи 08:00)
        op.execute("""
            UPDATE timesheets 
            SET work_start = (work_date + interval '8 hours')::timestamp with time zone,
                work_end = (work_date + interval '8 hours' + 
                           (hours_worked || ' hours')::interval +
                           (minutes_worked || ' minutes')::interval)::timestamp with time zone,
                duration_minutes = hours_worked * 60 + minutes_worked
            WHERE work_date IS NOT NULL
        """)
        
        # Видаляємо старі
        op.drop_column('timesheets', 'work_date')
        if 'hours_worked' in columns:
            op.drop_column('timesheets', 'hours_worked')
        if 'minutes_worked' in columns:
            op.drop_column('timesheets', 'minutes_worked')
        
        # NOT NULL
        op.alter_column('timesheets', 'work_start', nullable=False)
        op.alter_column('timesheets', 'work_end', nullable=False)
    
    # Додаткові поля
    op.add_column('timesheets',
        sa.Column('break_minutes', sa.Integer(), default=0, server_default='0')
    )
    op.add_column('timesheets',
        sa.Column('overtime_minutes', sa.Integer(), default=0, server_default='0')
    )
    
    op.create_index('idx_timesheets_position_time', 'timesheets',
                    ['position_id', 'work_start', 'work_end'])
    
    # ========== 8. CONTRACTS - TIMESTAMP ==========
    print("Converting contracts to TIMESTAMP...")
    
    columns = [col['name'] for col in inspector.get_columns('contracts')]
    
    if 'start_date' in columns:
        op.add_column('contracts',
            sa.Column('start_datetime', sa.TIMESTAMP(timezone=True), nullable=True)
        )
        op.add_column('contracts',
            sa.Column('end_datetime', sa.TIMESTAMP(timezone=True), nullable=True)
        )
        
        op.execute("""
            UPDATE contracts 
            SET start_datetime = start_date::timestamp with time zone
            WHERE start_date IS NOT NULL
        """)
        op.execute("""
            UPDATE contracts 
            SET end_datetime = end_date::timestamp with time zone
            WHERE end_date IS NOT NULL
        """)
        
        op.drop_column('contracts', 'start_date')
        op.drop_column('contracts', 'end_date')
        
        op.alter_column('contracts', 'start_datetime', nullable=False)
    
    # ========== 9. ACCRUAL_RESULTS - Аудит ==========
    print("Adding audit fields to accrual_results...")
    
    op.add_column('accrual_results',
        sa.Column('rule_source_type', sa.String(20), nullable=True)
    )
    op.add_column('accrual_results',
        sa.Column('rule_source_id', sa.Integer(), nullable=True)
    )
    
    # Оновити існуючі записи
    op.execute("""
        UPDATE accrual_results
        SET rule_source_type = 'global'
        WHERE rule_source_type IS NULL
    """)
    
    # ========== 10. SPLIT_REASONS - Довідник ==========
    print("Creating split_reasons table...")
    
    op.create_table(
        'split_reasons',
        sa.Column('code', sa.String(50), primary_key=True),
        sa.Column('name', sa.String(255), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('auto_split', sa.Boolean(), default=True),
        sa.Column('created_at', sa.TIMESTAMP(timezone=True), server_default=sa.text('NOW()'))
    )
    
    # Заповнити довідник
    op.execute("""
        INSERT INTO split_reasons (code, name, description, auto_split) VALUES
        ('RATE_CHANGE', 'Зміна ставки', 'Змінилась employment_rate позиції', true),
        ('CONTRACT_RATE_CHANGE', 'Зміна окладу', 'Змінилась base_rate в контракті', true),
        ('CONTRACT_TYPE_CHANGE', 'Зміна типу контракту', 'Зміна salary → hourly', true),
        ('GROUP_ADDED', 'Додана група', 'Позиція додана до групи', true),
        ('GROUP_REMOVED', 'Видалена група', 'Позиція видалена з групи', true),
        ('RULE_CHANGED', 'Зміна правила', 'Створена нова версія правила', true),
        ('SCHEDULE_CHANGE', 'Зміна графіку', 'Зміна денної/нічної зміни', true),
        ('MIDNIGHT_SPLIT', 'Перехід через опівніч', 'Автоматичне розбиття', true),
        ('MANUAL_SPLIT', 'Ручне розбиття', 'Оператор розбив період', false)
    """)
    
    # ========== 11. MATERIALIZED VIEW ==========
    print("Creating accrual_summary materialized view...")
    
    op.execute("""
        CREATE MATERIALIZED VIEW accrual_summary AS
        SELECT 
            ad.id as document_id,
            ad.document_number,
            ad.status as document_status,
            cp.period_code,
            cp.period_name,
            cp.start_datetime,
            cp.end_datetime,
            ct.name as template_name,
            
            e.id as employee_id,
            e.personnel_number,
            e.first_name || ' ' || e.last_name as employee_name,
            
            p.id as position_id,
            p.position_name,
            p.employment_rate,
            
            ou.id as org_unit_id,
            ou.name as org_unit_name,
            ou.code as org_unit_code,
            
            ar.rule_id,
            ar.rule_code,
            cr.name as rule_name,
            cr.rule_type,
            ar.rule_source_type,
            ar.rule_source_id,
            
            ar.amount,
            ar.calculation_base,
            ar.currency,
            
            ar.created_at
            
        FROM accrual_documents ad
        JOIN calculation_periods cp ON cp.id = ad.period_id
        JOIN calculation_templates ct ON ct.id = ad.template_id
        JOIN accrual_results ar ON ar.document_id = ad.id
        JOIN positions p ON p.id = ar.position_id
        JOIN employees e ON e.id = ar.employee_id
        JOIN organizational_units ou ON ou.id = ar.organizational_unit_id
        JOIN calculation_rules cr ON cr.id = ar.rule_id
        
        WHERE ar.status = 'active'
        
        ORDER BY ad.id, e.personnel_number, ar.created_at
    """)
    
    # Індекси
    op.execute("CREATE INDEX idx_accrual_summary_document ON accrual_summary(document_id)")
    op.execute("CREATE INDEX idx_accrual_summary_employee ON accrual_summary(employee_id)")
    op.execute("CREATE INDEX idx_accrual_summary_period ON accrual_summary(period_code)")
    
    print("Migration completed successfully! ✅")


def downgrade():
    """
    Відкат змін (складний, краще не використовувати в продакшн)
    """
    print("Rolling back migration...")
    
    # VIEW
    op.execute("DROP MATERIALIZED VIEW IF EXISTS accrual_summary")
    
    # Tables
    op.drop_table('split_reasons')
    op.drop_table('position_schedules')
    op.drop_table('shift_schedules')
    op.drop_table('position_groups')
    
    # Groups parent_id
    op.drop_constraint('fk_groups_parent', 'groups', type_='foreignkey')
    op.drop_index('idx_groups_parent', 'groups')
    op.drop_index('idx_groups_level', 'groups')
    op.drop_column('groups', 'parent_id')
    op.drop_column('groups', 'level')
    op.drop_column('groups', 'full_path')
    
    # Calculation Rules
    op.drop_constraint('fk_rules_group', 'calculation_rules', type_='foreignkey')
    op.drop_constraint('fk_rules_replaces', 'calculation_rules', type_='foreignkey')
    op.drop_index('idx_rules_group_dates', 'calculation_rules')
    op.drop_index('idx_rules_replaces', 'calculation_rules')
    op.drop_index('idx_rules_code_dates', 'calculation_rules')
    
    op.drop_column('calculation_rules', 'group_id')
    op.drop_column('calculation_rules', 'time_of_day_start')
    op.drop_column('calculation_rules', 'time_of_day_end')
    op.drop_column('calculation_rules', 'days_of_week')
    op.drop_column('calculation_rules', 'version')
    op.drop_column('calculation_rules', 'replaces_rule_id')
    op.drop_column('calculation_rules', 'combination_mode')
    op.drop_column('calculation_rules', 'priority')
    op.drop_column('calculation_rules', 'exclusion_groups')
    op.drop_column('calculation_rules', 'max_combined_amount')
    
    # Periods
    op.drop_constraint('fk_periods_parent', 'calculation_periods', type_='foreignkey')
    op.drop_index('idx_periods_parent', 'calculation_periods')
    op.drop_index('idx_periods_datetime', 'calculation_periods')
    
    op.drop_column('calculation_periods', 'split_reason')
    op.drop_column('calculation_periods', 'parent_period_id')
    op.drop_column('calculation_periods', 'conditions_snapshot')
    
    # Accrual Results
    op.drop_column('accrual_results', 'rule_source_type')
    op.drop_column('accrual_results', 'rule_source_id')
    
    # Timesheets
    op.drop_index('idx_timesheets_position_time', 'timesheets')
    op.drop_column('timesheets', 'break_minutes')
    op.drop_column('timesheets', 'overtime_minutes')
    
    print("Rollback completed.")