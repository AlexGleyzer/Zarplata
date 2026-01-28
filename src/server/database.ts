import Database from 'better-sqlite3';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const projectRoot = join(__dirname, '..', '..');
const dbPath = join(projectRoot, 'data', 'payroll.db');

export const db = new Database(dbPath);

// Типи для даних
export interface Employee {
  id?: number;
  full_name: string;
  position: string;
  hourly_rate: number;
  hire_date: string;
  status: 'active' | 'inactive';
  created_at?: string;
  updated_at?: string;
}

export interface WorkHours {
  id?: number;
  employee_id: number;
  work_date: string;
  hours_worked: number;
  overtime_hours: number;
  notes?: string;
  created_at?: string;
}

export interface Payroll {
  id?: number;
  employee_id: number;
  period_start: string;
  period_end: string;
  regular_hours: number;
  overtime_hours: number;
  gross_salary: number;
  tax_amount: number;
  net_salary: number;
  payment_date?: string;
  status: 'pending' | 'paid' | 'cancelled';
  created_at?: string;
}

// Підготовлені запити для працівників
export const employeeQueries = {
  getAll: db.prepare('SELECT * FROM employees WHERE status = ? ORDER BY full_name'),
  getById: db.prepare('SELECT * FROM employees WHERE id = ?'),
  create: db.prepare(`
    INSERT INTO employees (full_name, position, hourly_rate, hire_date, status)
    VALUES (@full_name, @position, @hourly_rate, @hire_date, @status)
  `),
  update: db.prepare(`
    UPDATE employees
    SET full_name = @full_name, position = @position, hourly_rate = @hourly_rate,
        status = @status, updated_at = CURRENT_TIMESTAMP
    WHERE id = @id
  `),
  delete: db.prepare('UPDATE employees SET status = ? WHERE id = ?')
};

// Підготовлені запити для робочих годин
export const workHoursQueries = {
  getByEmployee: db.prepare(`
    SELECT * FROM work_hours
    WHERE employee_id = ? AND work_date BETWEEN ? AND ?
    ORDER BY work_date DESC
  `),
  create: db.prepare(`
    INSERT INTO work_hours (employee_id, work_date, hours_worked, overtime_hours, notes)
    VALUES (@employee_id, @work_date, @hours_worked, @overtime_hours, @notes)
  `),
  update: db.prepare(`
    UPDATE work_hours
    SET hours_worked = @hours_worked, overtime_hours = @overtime_hours, notes = @notes
    WHERE id = @id
  `),
  delete: db.prepare('DELETE FROM work_hours WHERE id = ?')
};

// Підготовлені запити для розрахунку зарплати
export const payrollQueries = {
  getAll: db.prepare(`
    SELECT p.*, e.full_name, e.position
    FROM payroll p
    JOIN employees e ON p.employee_id = e.id
    WHERE p.period_start >= ? AND p.period_end <= ?
    ORDER BY p.period_start DESC
  `),
  getByEmployee: db.prepare(`
    SELECT * FROM payroll
    WHERE employee_id = ?
    ORDER BY period_start DESC
  `),
  create: db.prepare(`
    INSERT INTO payroll (
      employee_id, period_start, period_end, regular_hours, overtime_hours,
      gross_salary, tax_amount, net_salary, status
    ) VALUES (
      @employee_id, @period_start, @period_end, @regular_hours, @overtime_hours,
      @gross_salary, @tax_amount, @net_salary, @status
    )
  `),
  updateStatus: db.prepare('UPDATE payroll SET status = ?, payment_date = ? WHERE id = ?')
};
