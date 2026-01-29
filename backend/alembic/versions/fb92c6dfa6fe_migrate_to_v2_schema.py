"""migrate_to_v2_schema

Revision ID: fb92c6dfa6fe
Revises: 002_20260129120709_add_groups_hierarchy
Create Date: 2026-01-29 20:40:24.413815

Migration from v1.0 to v2.0 schema:
- Employees: Remove organizational_unit_id, add new fields
- Contracts: Change employee_id to position_id, change DATE to TIMESTAMP
- Timesheets: Change employee_id to position_id, change to TIMESTAMP-based tracking
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = 'fb92c6dfa6fe'
down_revision = '002_20260129120709_add_groups_hierarchy'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ============================================================
    # STEP 1: Ensure all employees have at least one position
    # ============================================================
    print("Step 1: Ensuring all employees have positions...")

    # Create positions for employees without them
    op.execute("""
        INSERT INTO positions (
            employee_id,
            organizational_unit_id,
            position_code,
            position_name,
            employment_rate,
            start_date,
            is_active,
            created_by
        )
        SELECT
            e.id,
            e.organizational_unit_id,
            'POS_' || e.personnel_number,
            'Position for ' || e.first_name || ' ' || e.last_name,
            1.0,
            e.hire_date,
            e.is_active,
            'migration_v2'
        FROM employees e
        LEFT JOIN positions p ON p.employee_id = e.id
        WHERE p.id IS NULL;
    """)

    # ============================================================
    # STEP 2: Drop materialized view temporarily
    # ============================================================
    print("Step 2: Dropping materialized view...")

    op.execute("DROP MATERIALIZED VIEW IF EXISTS accrual_summary;")

    # ============================================================
    # STEP 3: Add new columns to employees table
    # ============================================================
    print("Step 3: Adding new columns to employees table...")

    op.add_column('employees', sa.Column('tax_number', sa.String(length=50), nullable=True))
    op.add_column('employees', sa.Column('birth_date', sa.Date(), nullable=True))
    op.add_column('employees', sa.Column('email', sa.String(length=255), nullable=True))
    op.add_column('employees', sa.Column('phone', sa.String(length=50), nullable=True))
    op.add_column('employees', sa.Column('address', sa.Text(), nullable=True))
    op.add_column('employees', sa.Column('status', sa.String(length=20), server_default='active', nullable=True))
    op.add_column('employees', sa.Column('created_by', sa.String(length=100), server_default='migration_v2', nullable=False))

    # Update status based on is_active and termination_date
    op.execute("""
        UPDATE employees
        SET status = CASE
            WHEN termination_date IS NOT NULL THEN 'terminated'
            WHEN is_active = false THEN 'on_leave'
            ELSE 'active'
        END;
    """)

    # Update personnel_number length
    op.alter_column('employees', 'personnel_number',
                    existing_type=sa.VARCHAR(length=20),
                    type_=sa.VARCHAR(length=50),
                    existing_nullable=False)

    # Create indexes for new columns
    op.create_index(op.f('idx_employees_tax_number'), 'employees', ['tax_number'], unique=False)
    op.create_index(op.f('idx_employees_status'), 'employees', ['status'], unique=False)

    # ============================================================
    # STEP 4: Migrate contracts table to v2.0
    # ============================================================
    print("Step 4: Migrating contracts table...")

    # Add position_id column (nullable for now)
    op.add_column('contracts', sa.Column('position_id', sa.Integer(), nullable=True))

    # Map employee_id to position_id (use the first active position for each employee)
    op.execute("""
        UPDATE contracts c
        SET position_id = (
            SELECT p.id
            FROM positions p
            WHERE p.employee_id = c.employee_id
            ORDER BY p.is_active DESC, p.start_date ASC
            LIMIT 1
        );
    """)

    # Add new columns
    op.add_column('contracts', sa.Column('created_by', sa.String(length=100), server_default='migration_v2', nullable=False))
    op.add_column('contracts', sa.Column('notes', sa.Text(), nullable=True))

    # Change DATE columns to TIMESTAMP
    op.add_column('contracts', sa.Column('start_datetime', postgresql.TIMESTAMP(timezone=True), nullable=True))
    op.add_column('contracts', sa.Column('end_datetime', postgresql.TIMESTAMP(timezone=True), nullable=True))

    # Convert DATE to TIMESTAMP (set time to 00:00:00)
    op.execute("""
        UPDATE contracts
        SET start_datetime = start_date::timestamp with time zone,
            end_datetime = end_date::timestamp with time zone;
    """)

    # Make new columns NOT NULL where appropriate
    op.alter_column('contracts', 'start_datetime', nullable=False)
    op.alter_column('contracts', 'position_id', nullable=False)

    # Drop old columns
    op.drop_constraint('contracts_employee_id_fkey', 'contracts', type_='foreignkey')
    op.drop_constraint('contracts_organizational_unit_id_fkey', 'contracts', type_='foreignkey')
    op.drop_constraint('contracts_contract_number_key', 'contracts', type_='unique')
    op.drop_column('contracts', 'contract_number')
    op.drop_column('contracts', 'employee_id')
    op.drop_column('contracts', 'organizational_unit_id')
    op.drop_column('contracts', 'start_date')
    op.drop_column('contracts', 'end_date')

    # Add foreign key for position_id
    op.create_foreign_key('contracts_position_id_fkey', 'contracts', 'positions', ['position_id'], ['id'], ondelete='CASCADE')

    # Create index for position_id
    op.create_index(op.f('idx_contracts_position'), 'contracts', ['position_id'], unique=False)
    op.create_index(op.f('idx_contracts_dates'), 'contracts', ['start_datetime', 'end_datetime'], unique=False)

    # Add check constraint (may not exist in old schema)
    op.execute("ALTER TABLE contracts DROP CONSTRAINT IF EXISTS contract_dates_check;")
    op.create_check_constraint('contract_dates_check', 'contracts', 'end_datetime IS NULL OR end_datetime > start_datetime')

    # ============================================================
    # STEP 5: Migrate timesheets table to v2.0
    # ============================================================
    print("Step 5: Migrating timesheets table...")

    # Add position_id column (nullable for now)
    op.add_column('timesheets', sa.Column('position_id', sa.Integer(), nullable=True))

    # Map employee_id to position_id
    op.execute("""
        UPDATE timesheets t
        SET position_id = (
            SELECT p.id
            FROM positions p
            WHERE p.employee_id = t.employee_id
              AND p.organizational_unit_id = t.organizational_unit_id
            ORDER BY p.is_active DESC, p.start_date ASC
            LIMIT 1
        );
    """)

    # Handle cases where no matching position found (use any position for that employee)
    op.execute("""
        UPDATE timesheets t
        SET position_id = (
            SELECT p.id
            FROM positions p
            WHERE p.employee_id = t.employee_id
            ORDER BY p.is_active DESC, p.start_date ASC
            LIMIT 1
        )
        WHERE position_id IS NULL;
    """)

    # Add new timestamp columns
    op.add_column('timesheets', sa.Column('work_start', postgresql.TIMESTAMP(timezone=True), nullable=True))
    op.add_column('timesheets', sa.Column('work_end', postgresql.TIMESTAMP(timezone=True), nullable=True))
    op.add_column('timesheets', sa.Column('duration_minutes', sa.Integer(), nullable=True))
    op.add_column('timesheets', sa.Column('break_minutes', sa.Integer(), server_default='0', nullable=False))
    op.add_column('timesheets', sa.Column('overtime_minutes', sa.Integer(), server_default='0', nullable=False))
    op.add_column('timesheets', sa.Column('created_by', sa.String(length=100), server_default='migration_v2', nullable=False))
    op.add_column('timesheets', sa.Column('notes', sa.Text(), nullable=True))

    # Convert work_date + hours/minutes to timestamps
    # Assume work starts at 08:00 by default
    op.execute("""
        UPDATE timesheets
        SET work_start = (work_date + interval '8 hours')::timestamp with time zone,
            work_end = (work_date + interval '8 hours' +
                       (hours_worked * interval '1 hour') +
                       (minutes_worked * interval '1 minute'))::timestamp with time zone,
            duration_minutes = (hours_worked * 60 + minutes_worked);
    """)

    # Make new columns NOT NULL
    op.alter_column('timesheets', 'work_start', nullable=False)
    op.alter_column('timesheets', 'work_end', nullable=False)
    op.alter_column('timesheets', 'position_id', nullable=False)

    # Drop old columns
    op.drop_constraint('timesheets_employee_id_fkey', 'timesheets', type_='foreignkey')
    op.drop_constraint('timesheets_organizational_unit_id_fkey', 'timesheets', type_='foreignkey')
    op.drop_column('timesheets', 'employee_id')
    op.drop_column('timesheets', 'organizational_unit_id')
    op.drop_column('timesheets', 'work_date')
    op.drop_column('timesheets', 'hours_worked')
    op.drop_column('timesheets', 'minutes_worked')

    # Add foreign key for position_id
    op.create_foreign_key('timesheets_position_id_fkey', 'timesheets', 'positions', ['position_id'], ['id'], ondelete='CASCADE')

    # Create indexes
    op.create_index(op.f('idx_timesheets_position'), 'timesheets', ['position_id'], unique=False)
    op.create_index(op.f('idx_timesheets_time'), 'timesheets', ['work_start', 'work_end'], unique=False)

    # Add check constraints
    op.create_check_constraint('timesheet_time_check', 'timesheets', 'work_end > work_start')
    op.create_check_constraint('timesheet_break_check', 'timesheets', 'break_minutes >= 0')
    op.create_check_constraint('timesheet_overtime_check', 'timesheets', 'overtime_minutes >= 0')

    # Recreate trigger for duration calculation
    op.execute("""
        CREATE OR REPLACE FUNCTION calculate_timesheet_duration()
        RETURNS TRIGGER AS $$
        BEGIN
            NEW.duration_minutes := EXTRACT(EPOCH FROM (NEW.work_end - NEW.work_start)) / 60;
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
    """)

    op.execute("""
        DROP TRIGGER IF EXISTS trg_calculate_duration ON timesheets;
        CREATE TRIGGER trg_calculate_duration
            BEFORE INSERT OR UPDATE ON timesheets
            FOR EACH ROW
            EXECUTE FUNCTION calculate_timesheet_duration();
    """)

    # ============================================================
    # STEP 6: Remove organizational_unit_id from employees
    # ============================================================
    print("Step 6: Removing organizational_unit_id from employees...")

    # Drop foreign key and column (employees now connect to org units through positions)
    op.drop_constraint('employees_organizational_unit_id_fkey', 'employees', type_='foreignkey')
    op.drop_index('idx_employees_org_unit', table_name='employees')
    op.drop_column('employees', 'organizational_unit_id')

    print("Migration to v2.0 completed successfully!")
    print("Note: Materialized view accrual_summary was dropped and needs to be recreated if needed.")


def downgrade() -> None:
    """Downgrade from v2.0 to v1.0 schema"""
    print("Downgrading from v2.0 to v1.0...")

    # This is a complex downgrade - we'll restore the basic v1.0 structure
    # Some data may be lost in the downgrade process

    # Step 1: Restore organizational_unit_id to employees
    op.add_column('employees', sa.Column('organizational_unit_id', sa.Integer(), nullable=True))

    # Get org unit from first position
    op.execute("""
        UPDATE employees e
        SET organizational_unit_id = (
            SELECT p.organizational_unit_id
            FROM positions p
            WHERE p.employee_id = e.id
            ORDER BY p.is_active DESC, p.start_date ASC
            LIMIT 1
        );
    """)

    op.alter_column('employees', 'organizational_unit_id', nullable=False)
    op.create_foreign_key('employees_organizational_unit_id_fkey', 'employees', 'organizational_units',
                          ['organizational_unit_id'], ['id'])
    op.create_index('idx_employees_org_unit', 'employees', ['organizational_unit_id'])

    # Step 2: Restore timesheets v1.0 structure
    op.add_column('timesheets', sa.Column('employee_id', sa.Integer(), nullable=True))
    op.add_column('timesheets', sa.Column('organizational_unit_id', sa.Integer(), nullable=True))
    op.add_column('timesheets', sa.Column('work_date', sa.Date(), nullable=True))
    op.add_column('timesheets', sa.Column('hours_worked', sa.Integer(), nullable=True))
    op.add_column('timesheets', sa.Column('minutes_worked', sa.Integer(), server_default='0', nullable=True))

    # Convert back
    op.execute("""
        UPDATE timesheets t
        SET employee_id = p.employee_id,
            organizational_unit_id = p.organizational_unit_id,
            work_date = work_start::date,
            hours_worked = duration_minutes / 60,
            minutes_worked = duration_minutes % 60
        FROM positions p
        WHERE t.position_id = p.id;
    """)

    op.alter_column('timesheets', 'employee_id', nullable=False)
    op.alter_column('timesheets', 'organizational_unit_id', nullable=False)
    op.alter_column('timesheets', 'work_date', nullable=False)
    op.alter_column('timesheets', 'hours_worked', nullable=False)
    op.alter_column('timesheets', 'minutes_worked', nullable=False)

    op.drop_constraint('timesheets_position_id_fkey', 'timesheets', type_='foreignkey')
    op.drop_constraint('timesheet_time_check', 'timesheets', type_='check')
    op.drop_constraint('timesheet_break_check', 'timesheets', type_='check')
    op.drop_constraint('timesheet_overtime_check', 'timesheets', type_='check')
    op.drop_index('idx_timesheets_position', table_name='timesheets')
    op.drop_index('idx_timesheets_time', table_name='timesheets')

    op.drop_column('timesheets', 'notes')
    op.drop_column('timesheets', 'created_by')
    op.drop_column('timesheets', 'overtime_minutes')
    op.drop_column('timesheets', 'break_minutes')
    op.drop_column('timesheets', 'duration_minutes')
    op.drop_column('timesheets', 'work_end')
    op.drop_column('timesheets', 'work_start')
    op.drop_column('timesheets', 'position_id')

    op.create_foreign_key('timesheets_employee_id_fkey', 'timesheets', 'employees', ['employee_id'], ['id'])
    op.create_foreign_key('timesheets_organizational_unit_id_fkey', 'timesheets', 'organizational_units',
                          ['organizational_unit_id'], ['id'])

    # Step 3: Restore contracts v1.0 structure
    op.add_column('contracts', sa.Column('employee_id', sa.Integer(), nullable=True))
    op.add_column('contracts', sa.Column('organizational_unit_id', sa.Integer(), nullable=True))
    op.add_column('contracts', sa.Column('contract_number', sa.String(50), nullable=True))
    op.add_column('contracts', sa.Column('start_date', sa.Date(), nullable=True))
    op.add_column('contracts', sa.Column('end_date', sa.Date(), nullable=True))

    # Convert back
    op.execute("""
        UPDATE contracts c
        SET employee_id = p.employee_id,
            organizational_unit_id = p.organizational_unit_id,
            start_date = start_datetime::date,
            end_date = end_datetime::date,
            contract_number = 'CONTRACT_' || c.id
        FROM positions p
        WHERE c.position_id = p.id;
    """)

    op.alter_column('contracts', 'employee_id', nullable=False)
    op.alter_column('contracts', 'organizational_unit_id', nullable=False)
    op.alter_column('contracts', 'contract_number', nullable=False)
    op.alter_column('contracts', 'start_date', nullable=False)

    op.drop_constraint('contracts_position_id_fkey', 'contracts', type_='foreignkey')
    op.drop_constraint('contract_dates_check', 'contracts', type_='check')
    op.drop_index('idx_contracts_position', table_name='contracts')
    op.drop_index('idx_contracts_dates', table_name='contracts')

    op.drop_column('contracts', 'notes')
    op.drop_column('contracts', 'created_by')
    op.drop_column('contracts', 'end_datetime')
    op.drop_column('contracts', 'start_datetime')
    op.drop_column('contracts', 'position_id')

    op.create_foreign_key('contracts_employee_id_fkey', 'contracts', 'employees', ['employee_id'], ['id'])
    op.create_foreign_key('contracts_organizational_unit_id_fkey', 'contracts', 'organizational_units',
                          ['organizational_unit_id'], ['id'])
    op.create_unique_constraint('contracts_contract_number_key', 'contracts', ['contract_number'])
    op.create_check_constraint('contract_dates_check', 'contracts', 'end_date IS NULL OR end_date >= start_date')

    # Step 4: Remove new columns from employees
    op.drop_index('idx_employees_status', table_name='employees')
    op.drop_index('idx_employees_tax_number', table_name='employees')

    op.drop_column('employees', 'created_by')
    op.drop_column('employees', 'status')
    op.drop_column('employees', 'address')
    op.drop_column('employees', 'phone')
    op.drop_column('employees', 'email')
    op.drop_column('employees', 'birth_date')
    op.drop_column('employees', 'tax_number')

    op.alter_column('employees', 'personnel_number',
                    existing_type=sa.VARCHAR(length=50),
                    type_=sa.VARCHAR(length=20),
                    existing_nullable=False)

    print("Downgrade to v1.0 completed!")
