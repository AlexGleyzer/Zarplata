# Розрахунок з урахуванням змін всередині періоду

## Концепція підперіодів

Коли всередині розрахункового періоду (місяця) відбуваються зміни, період розбивається на **підперіоди**. Кожен підперіод має свої параметри розрахунку.

```
        МІСЯЦЬ (01.02 - 29.02)
              │
    ┌─────────┼─────────┐
    ↓         ↓         ↓
ПІДПЕРІОД 1  ЗМІНА  ПІДПЕРІОД 2
01.02-14.02         15.02-29.02
Оклад 20K           Оклад 25K
```

## Види змін що створюють підперіоди

| Код | Назва | Опис |
|-----|-------|------|
| `rate_change` | Зміна ставки/окладу | Підвищення або зниження |
| `transfer` | Переведення | На іншу посаду/підрозділ |
| `module_change` | Зміна модуля | Перехід на іншу форму оплати |
| `rule_change` | Зміна правил | Зміна правил нарахування |
| `tax_change` | Зміна податків | Зміна ставок податків |
| `status_change` | Зміна статусу | Випробування → штат |
| `contract_change` | Зміна договору | Нові умови контракту |

## Приклад розрахунку

### Ситуація

Працівник: Іванов І.П.
- Період: Лютий 2024 (168 робочих годин)
- 01.02 - 14.02: Оклад 20,000 грн (80 годин)
- 15.02: Підвищення окладу до 25,000 грн
- 15.02 - 29.02: Оклад 25,000 грн (88 годин)

### Створення підперіодів

```sql
-- Підперіод 1
INSERT INTO payroll_subperiods (
    period_id, employee_id, subperiod_number,
    start_date, end_date, work_hours,
    change_type, change_description, params_snapshot
) VALUES (
    1, 101, 1,
    '2024-02-01', '2024-02-14', 80,
    NULL, NULL,
    '{"base_salary": 20000, "hourly_rate": 119.05}'
);

-- Підперіод 2 (після зміни)
INSERT INTO payroll_subperiods (
    period_id, employee_id, subperiod_number,
    start_date, end_date, work_hours,
    change_type, change_description, params_snapshot
) VALUES (
    1, 101, 2,
    '2024-02-15', '2024-02-29', 88,
    'rate_change', 'Підвищення окладу',
    '{"base_salary": 25000, "hourly_rate": 148.81}'
);
```

### Розрахунок

```javascript
function calculateWithSubperiods(employeeId, periodId) {
    const subperiods = getSubperiods(employeeId, periodId);
    let totalAmount = 0;
    const details = [];

    for (const sp of subperiods) {
        const params = JSON.parse(sp.params_snapshot);
        const amount = params.base_salary * (sp.work_hours / 168);

        details.push({
            subperiod: sp.subperiod_number,
            dates: `${sp.start_date} - ${sp.end_date}`,
            hours: sp.work_hours,
            salary: params.base_salary,
            amount: amount,
            change: sp.change_description
        });

        totalAmount += amount;
    }

    return {
        total: totalAmount,
        details: details
    };
}
```

### Результат

```
┌────────────────────────────────────────────────────┐
│ РОЗРАХУНКОВИЙ ЛИСТОК                               │
│ Іванов І.П. | Лютий 2024                           │
├────────────────────────────────────────────────────┤
│                                                    │
│ ПІДПЕРІОД 1 (01.02 - 14.02)                        │
│ Оклад: 20,000 грн                                  │
│ Відпрацьовано: 80 год з 168                        │
│ Розрахунок: 20,000 × (80/168) = 9,523.81 грн       │
│                                                    │
│ ─────────────────────────────────────────────────  │
│ ⚠️ ЗМІНА: Підвищення окладу з 15.02.2024          │
│ Було: 20,000 грн → Стало: 25,000 грн               │
│ Документ: Наказ №45 від 14.02.2024                 │
│ ─────────────────────────────────────────────────  │
│                                                    │
│ ПІДПЕРІОД 2 (15.02 - 29.02)                        │
│ Оклад: 25,000 грн                                  │
│ Відпрацьовано: 88 год з 168                        │
│ Розрахунок: 25,000 × (88/168) = 13,095.24 грн      │
│                                                    │
├────────────────────────────────────────────────────┤
│ РАЗОМ НАРАХОВАНО: 22,619.05 грн                    │
└────────────────────────────────────────────────────┘
```

## Структура розрахунку в БД

```sql
-- Зберігаємо деталі розрахунку
INSERT INTO accrual_calculation_structure (
    accrual_id, accrual_source,
    step_number, step_type, step_name,
    description, input_values, formula, output_value
) VALUES
-- Крок 1: Вхідні дані
(1001, 'doc_payroll_accruals', 1, 'input', 'Вхідні дані',
 'Параметри розрахунку',
 '{"base_salary":25000,"worked_hours":88,"norm_hours":168}',
 NULL, NULL),

-- Крок 2: Застосоване правило
(1001, 'doc_payroll_accruals', 2, 'rule', 'Правило',
 'Базовий оклад (з договору)',
 '{"rule_id":1,"source":"contract"}',
 'base_salary × (worked_hours / norm_hours)', NULL),

-- Крок 3: Розрахунок
(1001, 'doc_payroll_accruals', 3, 'calculation', 'Обчислення',
 '25000 × (88 / 168)',
 NULL, NULL, 13095.24),

-- Крок 4: Результат
(1001, 'doc_payroll_accruals', 4, 'result', 'Результат',
 'Підсумок підперіоду 2',
 NULL, NULL, 13095.24);

-- Зберігаємо зміну
INSERT INTO accrual_applied_changes (
    accrual_id, accrual_source,
    change_type, change_date,
    document_id, document_type,
    old_value, new_value,
    impact_description, amount_impact
) VALUES (
    1001, 'doc_payroll_accruals',
    'rate_change', '2024-02-15',
    45, 'order',
    '20000', '25000',
    'Підвищення окладу на 25%',
    3571.43  -- різниця в нарахуванні
);
```

## Автоматичне виявлення змін

```javascript
async function detectChanges(employeeId, periodStart, periodEnd) {
    const changes = [];

    // Перевіряємо зміни окладу
    const salaryChanges = await db.query(`
        SELECT * FROM doc_contract_amendments
        WHERE employee_id = ?
          AND change_type = 'salary_change'
          AND effective_date BETWEEN ? AND ?
          AND status = 'posted'
        ORDER BY effective_date
    `, [employeeId, periodStart, periodEnd]);

    for (const change of salaryChanges) {
        changes.push({
            type: 'rate_change',
            date: change.effective_date,
            documentId: change.id,
            documentType: 'contract_amendment',
            oldValue: JSON.parse(change.old_values).base_salary,
            newValue: JSON.parse(change.new_values).base_salary
        });
    }

    // Перевіряємо переведення
    const transfers = await db.query(`
        SELECT * FROM employee_assignments
        WHERE employee_id = ?
          AND start_date BETWEEN ? AND ?
        ORDER BY start_date
    `, [employeeId, periodStart, periodEnd]);

    // ... інші види змін

    return changes.sort((a, b) => new Date(a.date) - new Date(b.date));
}
```

## Ієрархія правил при розрахунку

```
ІНДИВІДУАЛЬНИЙ ДОГОВІР (пріоритет 100) ← НАЙВИЩИЙ
   ↓ якщо немає
КАТЕГОРІЯ (пріоритет 50)
   ↓ якщо немає
ПОСАДА (пріоритет 40)
   ↓ якщо немає
ПІДРОЗДІЛ (пріоритет 30)
   ↓ якщо немає
ПІДПРИЄМСТВО (пріоритет 20)
   ↓ якщо немає
СИСТЕМА (пріоритет 10) ← НАЙНИЖЧИЙ
```

Правило з вищим пріоритетом **перевизначає** правило з нижчим.
