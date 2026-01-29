\# Залежності Таблиць - Система Розрахунку Зарплат



\## Огляд



Цей документ описує всі залежності між таблицями в системі.



---



\## 1. Дерева (Self-References)



\### Таблиці з Самопосиланням



| Таблиця | Поле | Посилається На | Тип Зв'язку |

|---------|------|----------------|-------------|

| `organizational\_units` | `parent\_id` | `organizational\_units.id` | SET NULL |

| `groups` | `parent\_id` | `groups.id` | SET NULL |

| `calculation\_periods` | `parent\_period\_id` | `calculation\_periods.id` | SET NULL |

| `calculation\_rules` | `replaces\_rule\_id` | `calculation\_rules.id` | SET NULL |



\*\*Особливості:\*\*

\- `parent\_id = NULL` → корінь дерева

\- `CHECK (id != parent\_id)` → захист від зациклення

\- `ON DELETE SET NULL` → при видаленні батька, діти стають корінням



---



\## 2. Основний Ланцюжок: Працівник → Позиція → Результати

```

employees (1)

&nbsp;   ↓

positions (N)

&nbsp;   ↓ ↓ ↓ ↓ ↓

&nbsp;   ├─ position\_groups (N)

&nbsp;   ├─ contracts (N)

&nbsp;   ├─ position\_schedules (N)

&nbsp;   ├─ timesheets (N)

&nbsp;   └─ accrual\_results (N)

```



\### Деталі



| З Таблиці | Поле | До Таблиці | Тип | ON DELETE |

|-----------|------|------------|-----|-----------|

| `positions` | `employee\_id` | `employees.id` | N:1 | CASCADE |

| `positions` | `organizational\_unit\_id` | `organizational\_units.id` | N:1 | RESTRICT |

| `position\_groups` | `position\_id` | `positions.id` | N:1 | CASCADE |

| `position\_groups` | `group\_id` | `groups.id` | N:1 | CASCADE |

| `contracts` | `position\_id` | `positions.id` | N:1 | CASCADE |

| `position\_schedules` | `position\_id` | `positions.id` | N:1 | CASCADE |

| `position\_schedules` | `schedule\_id` | `shift\_schedules.id` | N:1 | RESTRICT |

| `timesheets` | `position\_id` | `positions.id` | N:1 | CASCADE |

| `accrual\_results` | `position\_id` | `positions.id` | N:1 | RESTRICT |



\*\*Важливо:\*\*

\- При видаленні `employee` → видаляються всі його `positions` (CASCADE)

\- При видаленні `position` → видаляються `contracts`, `timesheets`, etc. (CASCADE)

\- При видаленні `position` → `accrual\_results` НЕ видаляються (RESTRICT) - захист історії!



---



\## 3. Правила Розрахунку (4 Рівні Scope)



\### Calculation Rules → Scope

```

calculation\_rules

&nbsp;   ├─ position\_id (0..1) → positions.id

&nbsp;   ├─ organizational\_unit\_id (0..1) → organizational\_units.id

&nbsp;   ├─ group\_id (0..1) → groups.id

&nbsp;   └─ (всі NULL) = ГЛОБАЛЬНЕ правило

```



| Поле | Посилається На | ON DELETE | Примітка |

|------|----------------|-----------|----------|

| `position\_id` | `positions.id` | CASCADE | Персональне правило |

| `organizational\_unit\_id` | `organizational\_units.id` | CASCADE | Правило підрозділу |

| `group\_id` | `groups.id` | SET NULL | Правило групи |

| всі NULL | - | - | Глобальне правило |



\*\*Constraint:\*\*

```sql

CHECK (

&nbsp;   (position\_id IS NOT NULL AND organizational\_unit\_id IS NULL AND group\_id IS NULL) OR

&nbsp;   (position\_id IS NULL AND organizational\_unit\_id IS NOT NULL AND group\_id IS NULL) OR

&nbsp;   (position\_id IS NULL AND organizational\_unit\_id IS NULL AND group\_id IS NOT NULL) OR

&nbsp;   (position\_id IS NULL AND organizational\_unit\_id IS NULL AND group\_id IS NULL)

)

```



Тільки \*\*ОДНЕ\*\* поле може бути NOT NULL!



---



\## 4. Шаблони → Правила (Слабкий Зв'язок)

```

calculation\_templates (1)

&nbsp;   ↓

template\_rules (N)

&nbsp;   ↓ (rule\_code, НЕ FK!)

calculation\_rules (N версій)

```



\### Особливості



| Таблиця | Поле | Тип Зв'язку | Примітка |

|---------|------|-------------|----------|

| `template\_rules` | `template\_id` | FK → `calculation\_templates.id` | CASCADE |

| `template\_rules` | `rule\_code` | \*\*НЕ FK!\*\* String | Шукається по коду + даті |



\*\*Чому НЕ Foreign Key?\*\*

\- Правило має багато версій (immutability)

\- При розрахунку шукається актуальна версія по `rule\_code` + `valid\_from`/`valid\_until`

\- Дозволяє змінювати правила без зміни шаблону



\*\*Приклад:\*\*

```sql

template\_rules: rule\_code = 'PIT'



calculation\_rules:

&nbsp; - id=1, code='PIT', valid\_from='2024-01-01', valid\_until='2024-04-14'

&nbsp; - id=2, code='PIT', valid\_from='2024-04-15', valid\_until=NULL



При розрахунку за квітень:

&nbsp; - До 14.04 використовується правило id=1

&nbsp; - З 15.04 використовується правило id=2

```



---



\## 5. Періоди → Документи → Результати

```

calculation\_periods (1)

&nbsp;   ↓

accrual\_documents (N)

&nbsp;   ↓

accrual\_results (N)

```



| З Таблиці | Поле | До Таблиці | ON DELETE |

|-----------|------|------------|-----------|

| `accrual\_documents` | `period\_id` | `calculation\_periods.id` | RESTRICT |

| `accrual\_documents` | `template\_id` | `calculation\_templates.id` | RESTRICT |

| `accrual\_documents` | `organizational\_unit\_id` | `organizational\_units.id` | SET NULL |

| `accrual\_results` | `document\_id` | `accrual\_documents.id` | CASCADE |

| `accrual\_results` | `position\_id` | `positions.id` | RESTRICT |

| `accrual\_results` | `employee\_id` | `employees.id` | RESTRICT |

| `accrual\_results` | `organizational\_unit\_id` | `organizational\_units.id` | RESTRICT |

| `accrual\_results` | `rule\_id` | `calculation\_rules.id` | RESTRICT |



\*\*Захист Історії:\*\*

\- Періоди НЕ можна видалити якщо є документи (RESTRICT)

\- Документи НЕ можна видалити якщо затверджені

\- Результати зберігаються навіть якщо працівник звільнився (RESTRICT)



---



\## 6. Денормалізація в accrual\_results



\### Чому Зберігаємо Дублікати?

```sql

accrual\_results {

&nbsp;   position\_id INTEGER,           -- ОСНОВНЕ

&nbsp;   employee\_id INTEGER,           -- ДЕНОРМАЛІЗАЦІЯ

&nbsp;   organizational\_unit\_id INTEGER -- ДЕНОРМАЛІЗАЦІЯ

}

```



\*\*Можна отримати з `positions`:\*\*

```sql

SELECT e.id, ou.id

FROM positions p

JOIN employees e ON e.id = p.employee\_id

JOIN organizational\_units ou ON ou.id = p.organizational\_unit\_id

WHERE p.id = :position\_id

```



\*\*Але зберігаємо окремо тому що:\*\*

1\. \*\*Швидкість\*\* - не треба JOIN для звітів

2\. \*\*Immutability\*\* - якщо працівник перейшов в інший підрозділ, старі результати залишаються з старим підрозділом

3\. \*\*Історія\*\* - навіть якщо позиція видалена, результати зберігають контекст



---



\## 7. Порядок Створення Таблиць (для міграції)



\### Без Залежностей (можна створювати першими)

```sql

1\. shift\_schedules

2\. split\_reasons (довідник)

```



\### Рівень 1 - Корінь Дерев

```sql

3\. organizational\_units (з parent\_id = NULL)

4\. groups (з parent\_id = NULL)

5\. employees

6\. calculation\_templates

```



\### Рівень 2 - Залежать від Рівня 1

```sql

7\. positions (залежить від employees, organizational\_units)

8\. calculation\_rules (залежить від positions, organizational\_units, groups)

9\. template\_rules (залежить від calculation\_templates)

10\. calculation\_periods (залежить від organizational\_units, employees)

```



\### Рівень 3 - Залежать від Позицій

```sql

11\. position\_groups (залежить від positions, groups)

12\. contracts (залежить від positions)

13\. position\_schedules (залежить від positions, shift\_schedules)

14\. timesheets (залежить від positions)

```



\### Рівень 4 - Документи

```sql

15\. accrual\_documents (залежить від calculation\_periods, calculation\_templates, organizational\_units)

```



\### Рівень 5 - Результати

```sql

16\. accrual\_results (залежить від accrual\_documents, positions, employees, organizational\_units, calculation\_rules)

```



\### Рівень 6 - Views

```sql

17\. accrual\_summary (materialized view, залежить від всіх таблиць)

```



---



\## 8. Порядок Видалення (для очищення БД)



\### ЗВОРОТНІЙ ПОРЯДОК!

```sql

-- Рівень 6

DROP MATERIALIZED VIEW IF EXISTS accrual\_summary;



-- Рівень 5

TRUNCATE accrual\_results CASCADE;



-- Рівень 4

TRUNCATE accrual\_documents CASCADE;



-- Рівень 3

TRUNCATE timesheets CASCADE;

TRUNCATE position\_schedules CASCADE;

TRUNCATE contracts CASCADE;

TRUNCATE position\_groups CASCADE;



-- Рівень 2

TRUNCATE calculation\_periods CASCADE;

TRUNCATE template\_rules CASCADE;

TRUNCATE calculation\_rules CASCADE;

TRUNCATE positions CASCADE;



-- Рівень 1

TRUNCATE calculation\_templates CASCADE;

TRUNCATE employees CASCADE;

TRUNCATE groups CASCADE;

TRUNCATE organizational\_units CASCADE;



-- Рівень 0

TRUNCATE shift\_schedules CASCADE;

TRUNCATE split\_reasons CASCADE;

```



\*\*Альтернатива (для dev):\*\*

```sql

-- Видалити всі дані зі ВСІХ таблиць одразу

DO $$ 

DECLARE

&nbsp;   r RECORD;

BEGIN

&nbsp;   FOR r IN (SELECT tablename FROM pg\_tables WHERE schemaname = 'public') 

&nbsp;   LOOP

&nbsp;       EXECUTE 'TRUNCATE TABLE ' || quote\_ident(r.tablename) || ' CASCADE';

&nbsp;   END LOOP;

END $$;

```



---



\## 9. Циклічні Залежності (Немає!)



\### Перевірка



\*\*Добре:\*\*

```

employees → positions → accrual\_results

(однонаправлений граф)

```



\*\*Погано (якби було):\*\*

```

employees → positions → contracts → employees

(цикл!)

```



\*\*Наша система НЕ має циклів\*\* ✅



---



\## 10. Materialized View: accrual\_summary



\### Залежності

```sql

accrual\_summary ЗАЛЕЖИТЬ ВІД:

&nbsp;   ├─ accrual\_documents

&nbsp;   ├─ calculation\_periods

&nbsp;   ├─ calculation\_templates

&nbsp;   ├─ accrual\_results

&nbsp;   ├─ positions

&nbsp;   ├─ employees

&nbsp;   ├─ organizational\_units

&nbsp;   ├─ calculation\_rules

&nbsp;   └─ groups (LEFT JOIN)

```



\### Оновлення



\*\*Автоматично НЕ оновлюється!\*\* Треба викликати вручну:

```sql

REFRESH MATERIALIZED VIEW accrual\_summary;



-- Або через функцію:

SELECT refresh\_accrual\_summary();



-- CONCURRENTLY (не блокує читання):

REFRESH MATERIALIZED VIEW CONCURRENTLY accrual\_summary;

```



\*\*Коли оновлювати?\*\*

\- Після створення документів нарахувань

\- Після затвердження документів

\- Раз на день (cron job)

\- За запитом користувача



---



\## 11. Граф Залежностей (Візуально)

```

&nbsp;                   shift\_schedules

&nbsp;                          ↓

&nbsp;   organizational\_units ← → groups

&nbsp;          ↓                   ↓

&nbsp;   employees              (ієрархія)

&nbsp;          ↓                   ↓

&nbsp;      positions ← ─ ─ ─ ─ position\_groups

&nbsp;     ↙  ↓  ↓  ↘               

contracts │  │  timesheets     

&nbsp;         │  │                 

position\_ │  │                 

schedules │  │                 

&nbsp;         ↓  ↓                 

&nbsp;   calculation\_rules          

&nbsp;         ↓                    

&nbsp;   calculation\_templates      

&nbsp;         ↓                    

&nbsp;   template\_rules             

&nbsp;         ↓                    

&nbsp;   calculation\_periods        

&nbsp;         ↓                    

&nbsp;   accrual\_documents          

&nbsp;         ↓                    

&nbsp;   accrual\_results            

&nbsp;         ↓                    

&nbsp;   accrual\_summary (VIEW)     

```



---



\## 12. Foreign Key Summary



\### Всього Foreign Keys: \*\*31\*\*



| Таблиця | Кількість FK | Примітка |

|---------|--------------|----------|

| `organizational\_units` | 1 | parent\_id |

| `groups` | 1 | parent\_id |

| `employees` | 0 | корінь |

| `positions` | 2 | employee, org\_unit |

| `position\_groups` | 2 | position, group |

| `contracts` | 1 | position |

| `shift\_schedules` | 0 | довідник |

| `position\_schedules` | 2 | position, schedule |

| `timesheets` | 1 | position |

| `calculation\_rules` | 6 | position, org\_unit, group, replaces (3 опціональні + 1 self) |

| `calculation\_templates` | 0 | корінь |

| `template\_rules` | 1 | template |

| `calculation\_periods` | 3 | org\_unit, employee, parent\_period (2 опціональні + 1 self) |

| `accrual\_documents` | 3 | period, template, org\_unit (1 опціональний) |

| `accrual\_results` | 5 | document, position, employee, org\_unit, rule |

| `split\_reasons` | 0 | довідник |



---



\## 13. Індекси на Foreign Keys



\### Автоматично Створені



PostgreSQL \*\*НЕ\*\* створює індекси на FK автоматично!



Ми створюємо \*\*вручну\*\* для всіх FK:

```sql

-- Приклади

CREATE INDEX idx\_positions\_employee ON positions(employee\_id);

CREATE INDEX idx\_positions\_org\_unit ON positions(organizational\_unit\_id);

CREATE INDEX idx\_position\_groups\_position ON position\_groups(position\_id);

CREATE INDEX idx\_position\_groups\_group ON position\_groups(group\_id);

CREATE INDEX idx\_accrual\_results\_document ON accrual\_results(document\_id);

-- etc...

```



\*\*Навіщо?\*\*

\- Прискорює JOIN

\- Прискорює перевірку FK constraints

\- Обов'язково для великих таблиць!



---



\## 14. Каскадне Видалення (CASCADE)



\### Де Використовується CASCADE



| Таблиця | FK | Дія |

|---------|----|----|

| `positions` | `employee\_id` | Видалити працівника → видалити всі його позиції |

| `position\_groups` | `position\_id` | Видалити позицію → видалити всі зв'язки з групами |

| `contracts` | `position\_id` | Видалити позицію → видалити всі контракти |

| `position\_schedules` | `position\_id` | Видалити позицію → видалити всі графіки |

| `timesheets` | `position\_id` | Видалити позицію → видалити весь табель |

| `calculation\_rules` | `position\_id` | Видалити позицію → видалити персональні правила |

| `template\_rules` | `template\_id` | Видалити шаблон → видалити всі правила шаблону |

| `accrual\_results` | `document\_id` | Видалити документ → видалити всі результати |



\### Де НЕ Використовується (RESTRICT) - Захист!



| Таблиця | FK | Захист Від |

|---------|----|----|

| `positions` | `organizational\_unit\_id` | Не можна видалити підрозділ з активними позиціями |

| `accrual\_documents` | `period\_id` | Не можна видалити період з документами |

| `accrual\_documents` | `template\_id` | Не можна видалити шаблон що використовується |

| `accrual\_results` | `position\_id` | \*\*НЕ можна видалити позицію якщо є нарахування\*\* |

| `accrual\_results` | `employee\_id` | Не можна видалити працівника з нарахуваннями |

| `accrual\_results` | `rule\_id` | Не можна видалити правило що використано |



---



\## 15. Перевірка Цілісності (Скрипти)



\### Знайти "Сироти" (Orphans)

```sql

-- Позиції без працівника (не повинно бути)

SELECT \* FROM positions p

WHERE NOT EXISTS (

&nbsp;   SELECT 1 FROM employees e WHERE e.id = p.employee\_id

);



-- Результати без документа (не повинно бути)

SELECT \* FROM accrual\_results ar

WHERE NOT EXISTS (

&nbsp;   SELECT 1 FROM accrual\_documents ad WHERE ad.id = ar.document\_id

);



-- Групи без батька що не є коренем

SELECT \* FROM groups g

WHERE parent\_id IS NOT NULL

&nbsp; AND NOT EXISTS (

&nbsp;     SELECT 1 FROM groups g2 WHERE g2.id = g.parent\_id

&nbsp; );

```



\### Знайти Цикли в Ієрархії

```sql

-- Перевірка циклів в organizational\_units

WITH RECURSIVE hierarchy AS (

&nbsp;   SELECT id, parent\_id, ARRAY\[id] as path, 1 as depth

&nbsp;   FROM organizational\_units

&nbsp;   WHERE parent\_id IS NULL

&nbsp;   

&nbsp;   UNION ALL

&nbsp;   

&nbsp;   SELECT ou.id, ou.parent\_id, h.path || ou.id, h.depth + 1

&nbsp;   FROM organizational\_units ou

&nbsp;   JOIN hierarchy h ON ou.parent\_id = h.id

&nbsp;   WHERE ou.id = ANY(h.path) = FALSE  -- якщо TRUE = є цикл!

)

SELECT \* FROM hierarchy WHERE depth > 100;  -- підозра на цикл

```



---



\## 16. Міграція Залежностей



\### При Додаванні Нової Таблиці



\*\*Checklist:\*\*

1\. ✅ Визначити всі FK

2\. ✅ Вибрати ON DELETE (CASCADE/RESTRICT/SET NULL)

3\. ✅ Створити індекси на FK

4\. ✅ Додати CHECK constraints

5\. ✅ Оновити документацію (цей файл!)

6\. ✅ Оновити ER діаграму

7\. ✅ Перевірити порядок створення/видалення



---



\## Кінець Документа



\*\*Версія:\*\* 2.0  

\*\*Дата:\*\* 2025-01-30  

\*\*Автор:\*\* Система розрахунку зарплат



\*\*Важливо:\*\* При зміні структури БД обов'язково оновлюй цей документ!

