# Концепція SCOPE - Області Застосування

## Огляд

**Scope (область застосування)** - це механізм, який дозволяє створювати періоди, нарахування та виплати для різних рівнів організації: від всього підприємства до окремого працівника.

## Типи Scope

| Тип | Опис | Приклад |
|-----|------|---------|
| `enterprise` | Все підприємство | Нарахувати ЗП всім працівникам |
| `department` | Підрозділ (+ дочірні) | Премія IT-відділу |
| `position` | Всі на посаді | Надбавка всім програмістам |
| `category` | Категорія працівників | Доплата інвалідам |
| `group` | Іменована група | Бонус команді проєкту |
| `employee` | Окремий працівник | Персональна премія |

## Структура в БД

```sql
-- Документ з scope
CREATE TABLE doc_payroll_calculations (
    ...
    scope_type TEXT DEFAULT 'enterprise',
    scope_id INTEGER,          -- ID підрозділу/посади/працівника
    scope_filter TEXT,         -- JSON з додатковими фільтрами
    ...
);
```

## Приклади використання

### 1. Все підприємство

```sql
INSERT INTO doc_payroll_calculations (
    document_number, period_id,
    scope_type, scope_id
) VALUES (
    'ЗП-2024-001', 1,
    'enterprise', NULL
);
```

### 2. Підрозділ

```sql
-- Нарахування для IT-відділу (включно з дочірніми підрозділами)
INSERT INTO doc_payroll_calculations (
    document_number, period_id,
    scope_type, scope_id
) VALUES (
    'ЗП-2024-002', 1,
    'department', 3  -- ID IT-департаменту
);
```

### 3. Підрозділ БЕЗ дочірніх

```sql
INSERT INTO doc_payroll_calculations (
    document_number, period_id,
    scope_type, scope_id,
    scope_filter
) VALUES (
    'ЗП-2024-003', 1,
    'department', 3,
    '{"include_children": false}'
);
```

### 4. Окремий працівник

```sql
INSERT INTO doc_payroll_calculations (
    document_number, period_id,
    scope_type, scope_id
) VALUES (
    'ПРЕМІЯ-2024-010', 1,
    'employee', 101  -- ID працівника
);
```

## Функція отримання працівників по scope

```javascript
async function getEmployeesByScope(scopeType, scopeId, options = {}) {
    switch (scopeType) {
        case 'enterprise':
            return db.query(`
                SELECT e.* FROM employees e
                JOIN employee_assignments ea ON ea.employee_id = e.id
                WHERE e.is_active = 1 AND ea.is_active = 1
            `);

        case 'department':
            const includeChildren = options.include_children !== false;
            if (includeChildren) {
                return db.query(`
                    SELECT DISTINCT e.* FROM employees e
                    JOIN employee_assignments ea ON ea.employee_id = e.id
                    JOIN departments d ON d.id = ea.department_id
                    JOIN departments parent ON parent.id = ?
                    WHERE e.is_active = 1
                      AND ea.is_active = 1
                      AND (d.id = parent.id OR d.full_path LIKE parent.full_path || '/%')
                `, [scopeId]);
            } else {
                return db.query(`
                    SELECT e.* FROM employees e
                    JOIN employee_assignments ea ON ea.employee_id = e.id
                    WHERE e.is_active = 1
                      AND ea.is_active = 1
                      AND ea.department_id = ?
                `, [scopeId]);
            }

        case 'position':
            return db.query(`
                SELECT e.* FROM employees e
                JOIN employee_assignments ea ON ea.employee_id = e.id
                WHERE e.is_active = 1
                  AND ea.is_active = 1
                  AND ea.position_id = ?
            `, [scopeId]);

        case 'category':
            return db.query(`
                SELECT e.* FROM employees e
                JOIN employee_category_membership ecm ON ecm.employee_id = e.id
                WHERE e.is_active = 1
                  AND ecm.is_active = 1
                  AND ecm.category_id = ?
            `, [scopeId]);

        case 'group':
            return db.query(`
                SELECT e.* FROM employees e
                JOIN employee_group_members egm ON egm.employee_id = e.id
                WHERE e.is_active = 1
                  AND egm.group_id = ?
            `, [scopeId]);

        case 'employee':
            return db.query(`
                SELECT * FROM employees WHERE id = ? AND is_active = 1
            `, [scopeId]);

        default:
            throw new Error(`Unknown scope type: ${scopeType}`);
    }
}
```

## Права доступу на основі Scope

Дозволи можуть обмежуватись scope:

```sql
-- Бухгалтер може нараховувати тільки для свого підрозділу
INSERT INTO role_permissions (
    role_id, permission_id,
    scope_type, scope_id
) VALUES (
    4, 7,  -- accountant, calculations_run
    'department', 3  -- тільки IT-відділ
);
```

## UI Командного інтерфейсу

При виборі scope в командному інтерфейсі:

```
┌────────────────────────────────────────┐
│ Для кого?                              │
├────────────────────────────────────────┤
│ ○ 🏢 Все підприємство (67)            │
│ ○ 🏛️ Підрозділ ▼                      │
│ ○ 💼 Посада ▼                          │
│ ○ 👥 Категорія ▼                       │
│ ○ 👤 Людина ▼                          │
└────────────────────────────────────────┘
```

При виборі "Підрозділ":

```
┌────────────────────────────────────────┐
│ Який підрозділ?                        │
├────────────────────────────────────────┤
│ ● Весь підрозділ (12)  ← ЗАВЖДИ ПЕРШИЙ│
├────────────────────────────────────────┤
│ ○ Розробка (8)                        │
│ ○ Тестування (3)                      │
│ ○ DevOps (1)                          │
└────────────────────────────────────────┘
```
