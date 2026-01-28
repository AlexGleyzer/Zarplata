import Database from 'better-sqlite3';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { existsSync, mkdirSync } from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const projectRoot = join(__dirname, '..');
const dbPath = join(projectRoot, 'data', 'payroll.db');

// Створюємо директорію data якщо не існує
const dataDir = join(projectRoot, 'data');
if (!existsSync(dataDir)) {
  mkdirSync(dataDir, { recursive: true });
}

const db = new Database(dbPath);

// Створюємо таблиці
db.exec(`
  -- Таблиця працівників
  CREATE TABLE IF NOT EXISTS employees (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    full_name TEXT NOT NULL,
    position TEXT NOT NULL,
    hourly_rate REAL NOT NULL,
    hire_date TEXT NOT NULL,
    status TEXT DEFAULT 'active' CHECK(status IN ('active', 'inactive')),
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
  );

  -- Таблиця табелю робочого часу
  CREATE TABLE IF NOT EXISTS work_hours (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL,
    work_date TEXT NOT NULL,
    hours_worked REAL NOT NULL,
    overtime_hours REAL DEFAULT 0,
    notes TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
    UNIQUE(employee_id, work_date)
  );

  -- Таблиця нарахувань зарплати
  CREATE TABLE IF NOT EXISTS payroll (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL,
    period_start TEXT NOT NULL,
    period_end TEXT NOT NULL,
    regular_hours REAL NOT NULL,
    overtime_hours REAL DEFAULT 0,
    gross_salary REAL NOT NULL,
    tax_amount REAL DEFAULT 0,
    net_salary REAL NOT NULL,
    payment_date TEXT,
    status TEXT DEFAULT 'pending' CHECK(status IN ('pending', 'paid', 'cancelled')),
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE
  );

  -- Індекси для оптимізації
  CREATE INDEX IF NOT EXISTS idx_work_hours_employee ON work_hours(employee_id);
  CREATE INDEX IF NOT EXISTS idx_work_hours_date ON work_hours(work_date);
  CREATE INDEX IF NOT EXISTS idx_payroll_employee ON payroll(employee_id);
  CREATE INDEX IF NOT EXISTS idx_payroll_period ON payroll(period_start, period_end);
`);

console.log('✓ База даних успішно ініціалізована:', dbPath);
console.log('✓ Створено таблиці: employees, work_hours, payroll');

db.close();
