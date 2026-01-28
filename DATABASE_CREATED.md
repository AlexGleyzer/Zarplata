# Database Documentation

## Overview

**Zarplata** is a payroll management system using SQLite as its database engine.

## Database Configuration

| Property | Value |
|----------|-------|
| **Engine** | SQLite |
| **File Location** | `data/payroll.db` |
| **Backups Directory** | `data/backups/` |

## Setup Instructions

### 1. Create the data directory

```bash
mkdir -p data/backups
```

### 2. Initialize the database

The database file (`payroll.db`) will be created automatically when the application first connects to SQLite.

## Database Schema

### employees

Stores employee information.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique employee ID |
| first_name | TEXT | NOT NULL | Employee first name |
| last_name | TEXT | NOT NULL | Employee last name |
| email | TEXT | UNIQUE | Employee email address |
| hire_date | DATE | NOT NULL | Date of employment |
| department_id | INTEGER | FOREIGN KEY | Reference to departments |
| position | TEXT | | Job position/title |
| salary | REAL | NOT NULL | Base salary amount |
| is_active | INTEGER | DEFAULT 1 | Employment status (1=active, 0=inactive) |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Record creation timestamp |
| updated_at | DATETIME | | Last update timestamp |

### departments

Stores department information.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique department ID |
| name | TEXT | NOT NULL UNIQUE | Department name |
| manager_id | INTEGER | FOREIGN KEY | Reference to employees |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Record creation timestamp |

### payroll_records

Stores payroll transaction records.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique payroll record ID |
| employee_id | INTEGER | FOREIGN KEY NOT NULL | Reference to employees |
| pay_period_start | DATE | NOT NULL | Start of pay period |
| pay_period_end | DATE | NOT NULL | End of pay period |
| gross_salary | REAL | NOT NULL | Gross salary amount |
| deductions | REAL | DEFAULT 0 | Total deductions |
| net_salary | REAL | NOT NULL | Net salary (gross - deductions) |
| payment_date | DATE | | Date of payment |
| status | TEXT | DEFAULT 'pending' | Payment status (pending/paid/cancelled) |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Record creation timestamp |

### deductions

Stores deduction types and amounts.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique deduction ID |
| payroll_id | INTEGER | FOREIGN KEY NOT NULL | Reference to payroll_records |
| type | TEXT | NOT NULL | Deduction type (tax/insurance/other) |
| description | TEXT | | Deduction description |
| amount | REAL | NOT NULL | Deduction amount |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Record creation timestamp |

## Entity Relationships

```
departments 1──────< employees
                        │
                        │
employees 1────────< payroll_records
                        │
                        │
payroll_records 1──< deductions
```

- One **department** has many **employees**
- One **employee** has many **payroll_records**
- One **payroll_record** has many **deductions**

## Backup Strategy

Database backups are stored in `data/backups/` and should follow the naming convention:

```
payroll_YYYY-MM-DD_HH-MM-SS.db
```

## Notes

- SQLite database file is excluded from version control via `.gitignore`
- Always ensure the `data/` directory exists before running the application
- Run database migrations before first use
