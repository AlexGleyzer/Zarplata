# DB_SCHEMA.md
# Схема бази даних для системи "Зарплата"

## 0. Загальна картинка

Основні групи таблиць:

### Працівники й їхні стани

- `employees` — працівники
- `employee_categories_history` — категорії/пільги працівника по періодах
- `employee_org_unit_history` — належність працівника до підрозділів по періодах

### Типи і правила розрахунків

- `accrual_types` — типи нарахувань/утримань
- `rule_versions` — версії правил розрахунку по типах
- `base_values` — загальні базові величини (мінімалка, прожитковий тощо)
- `employee_bases` — персональні бази (оклади, ставки тощо)

### Нарахування (борг)

- `accrual_operations` — логічні операції нарахувань/утримань
- `accrual_parts` — розбиття операцій на підперіоди

### Виплати (факт)

- `payment_operations` — факти виплат (платіжні операції)
- `payment_accrual_links` — зв’язок між виплатами та нарахуваннями

### Організаційна структура

- `org_units` — дерево підрозділів підприємства
- `employee_org_unit_history` — історія закріплення працівників за підрозділами

### Календар, зміни і робочий час

- `calendar_days` — календар днів (робочі, вихідні, свята, перенесення)
- `shift_types` — типи змін
- `shift_rules` — правила нарахувань по змінах
- `work_day_records` — фактичний облік робочого часу по днях

### Системне

- `schema_meta` — версія схеми / службова інформація (або аналог через таблицю міграцій)


---

## 1. Працівники

### 1.1. `employees`

**Призначення:**  
Хто взагалі існує в системі.

**Поля:**

- `id` — INTEGER, PK
- `code` — TEXT, внутрішній табельний/код працівника (унікальний, може бути NULL для “старих” записів)
- `full_name` — TEXT, ПІБ
- `tax_id` — TEXT, ІПН (опційно)
- `hired_at` — DATE, дата прийому
- `fired_at` — DATE, дата звільнення (NULL — ще працює)
- `created_at` — DATETIME
- `updated_at` — DATETIME

**Сенс:**

- за `hired_at` / `fired_at` можна сказати, чи працівник “активний” на певну дату.


### 1.2. `employee_categories_history`

**Призначення:**  
Категорії/пільги працівника по часу (інвалідність, неповнолітній, пільги, форма зайнятості тощо).

**Поля:**

- `id` — INTEGER, PK
- `employee_id` — INTEGER, FK → `employees.id`
- `category_code` — TEXT, код категорії (`DISABLED_GROUP_1`, `MINOR`, `FULL_TIME`, `PART_TIME`, ...)
- `valid_from` — DATE, початок дії
- `valid_to` — DATE, кінець дії (NULL = діє зараз)
- `comment` — TEXT, опціонально

**Інваріанти:**

- категорії не редагуються заднім числом; при зміні — закриваємо старий запис `valid_to`, додаємо новий з `valid_from`.
- на один момент часу по кожному типу категорії — не більше одного активного запису.


---

## 2. Типи і правила розрахунків

### 2.1. `accrual_types`

**Призначення:**  
ЩО саме ми нараховуємо / утримуємо.

**Поля:**

- `id` — INTEGER, PK
- `code` — TEXT, унікальний код (`SALARY`, `PIT`, `WAR_TAX`, `ESV_EMPLOYER`, `SICK`, `MATERNITY` …)
- `name` — TEXT, людська назва (“Основна зарплата”, “ПДФО”, …)
- `direction` — TEXT, напрям:
  - `INCOME` — дохід працівника
  - `WITHHOLDING` — утримання із зарплати
  - `EMPLOYER_CONTRIBUTION` — внесок роботодавця
- `category` — TEXT, група: `WAGE`, `TAX`, `COMPENSATION`, `BENEFIT`, …
- `is_active` — INTEGER (0/1), щоб не видаляти фізично

**Інваріанти:**

- `code` унікальний.
- нарахування/утримання завжди посилаються на `accrual_types`.


### 2.2. `rule_versions`

**Призначення:**  
Конкретні правила розрахунку в часі, прив’язані до типу нарахування.

**Поля:**

- `id` — INTEGER, PK
- `accrual_type_id` — INTEGER, FK → `accrual_types.id`
- `valid_from` — DATE, початок дії (включно)
- `valid_to` — DATE, кінець дії (NULL = діє досі)
- `base_kind` — TEXT, від чого рахуємо:
  - `GROSS_WAGE`, `AVG_DAILY`, `MIN_WAGE`, `TAXABLE_BASE`, …
- `calculation_mode` — TEXT, режим розрахунку:
  - `MONTHLY` — місячний оклад
  - `HOURLY` — погодинно
  - `DAILY` — поденно
  - `PIECE` — відрядна
  - `PERCENT` — відсоток від бази
  - `LUMP_SUM` — разова сума
- `human_description` — TEXT, опис словами для бухгалтера
- `formula_dsl` — TEXT, машинне представлення формули (DSL)
- `flags_json` — TEXT (JSON), додаткові параметри:
  - напр. `{"enters_pit_base": true, "enters_esv_base": false, ...}`

**Інваріанти:**

- для конкретного `accrual_type_id` на одну дату має бути не більше одного активного правила.
- старі правила не змінюємо — тільки додаємо нові з новим `valid_from`.


### 2.3. `base_values`

**Призначення:**  
Загальні законодавчі базові величини (мінімальна зарплата, прожитковий, база ЄСВ і т.д.).

**Поля:**

- `id` — INTEGER, PK
- `base_code` — TEXT, код (`MIN_WAGE`, `LIVING_MINIMUM`, `ESV_MAX_BASE`, …)
- `value` — INTEGER, значення (у копійках/мінорних одиницях)
- `valid_from` — DATE
- `valid_to` — DATE, NULL = діє
- `comment` — TEXT

**Інваріанти:**

- на одну `base_code` і дату — не більше одного активного значення.


### 2.4. `employee_bases`

**Призначення:**  
Персональні бази: оклади, погодинні ставки тощо.

**Поля:**

- `id` — INTEGER, PK
- `employee_id` — INTEGER, FK → `employees.id`
- `base_code` — TEXT, код (`MONTHLY_SALARY`, `HOURLY_RATE`, `PIECE_RATE_A`, `PERCENT_RATE_SALES`, …)
- `value` — INTEGER, значення (копійки)
- `valid_from` — DATE
- `valid_to` — DATE, NULL = діє

**Інваріанти:**

- на одного працівника + `base_code` + одну дату — не більше одного активного запису.
- змінюється тільки через документи-накази (див. принцип документів у CONCEPT.md).


---

## 3. Нарахування (борг)

### 3.1. `accrual_operations`

**Призначення:**  
Логічна операція нарахування/утримання за певний період (борг/зобов’язання).

**Поля:**

- `id` — INTEGER, PK
- `operation_code` — TEXT, унікальний код операції (для лінкування з виплатами)
- `employee_id` — INTEGER, FK → `employees.id`
- `accrual_type_id` — INTEGER, FK → `accrual_types.id`
- `rule_version_id` — INTEGER, FK → `rule_versions.id`
- `period_from` — DATE, початок періоду
- `period_to` — DATE, кінець періоду
- `total_amount` — INTEGER, загальна сума (копійки)
- `created_at` — DATETIME
- `created_by` — TEXT, хто/що створив

**Сенс:**

- це “одна історія боргу”.
- потім по ній можна частково/повністю проводити виплати.


### 3.2. `accrual_parts`

**Призначення:**  
Розбиття однієї операції на підперіоди, якщо в періоді змінювались бази/правила/категорії.

**Поля:**

- `id` — INTEGER, PK
- `accrual_operation_id` — INTEGER, FK → `accrual_operations.id`
- `part_from` — DATE, початок підперіоду
- `part_to` — DATE, кінець підперіоду
- `base_snapshot_json` — TEXT, зріз баз (оклад, ставки, категорія і т.д. для цього підперіоду)
- `amount` — INTEGER, сума за підперіод
- `calc_details_json` — TEXT, деталі розрахунку (години/дні, інтермедіатні величини, застосовані коефіцієнти)

**Інваріанти:**

- підперіоди в межах однієї `accrual_operation`:
  - покривають весь логічний період без дірок,
  - не перетинаються між собою.
- `total_amount` у `accrual_operations` = сума `amount` з `accrual_parts`.


---

## 4. Виплати

### 4.1. `payment_operations`

**Призначення:**  
Фактичні платежі (куди пішли гроші).

**Поля:**

- `id` — INTEGER, PK
- `payment_code` — TEXT, код/номер платіжки
- `payment_date` — DATE
- `total_amount` — INTEGER, загальна сума (знак за домовленістю)
- `recipient_type` — TEXT (`EMPLOYEE`, `BUDGET`, `FUND`, …)
- `recipient_employee_id` — INTEGER, FK → `employees.id` (якщо це працівник)
- `note` — TEXT
- `created_at` — DATETIME
- `created_by` — TEXT

**Сенс:**

- це факт грошової операції, незалежно від того, до яких боргів вона буде віднесена.


### 4.2. `payment_accrual_links`

**Призначення:**  
Зв’язок між платежем і нарахуванням (один платіж може гасити багато боргів і навпаки).

**Поля:**

- `id` — INTEGER, PK
- `payment_id` — INTEGER, FK → `payment_operations.id`
- `accrual_operation_id` — INTEGER, FK → `accrual_operations.id`
- `amount` — INTEGER, сума, яка з цього платежу погашає саме цю операцію

**Сенс:**

- дає можливість:
  - по кожній `accrual_operation` порахувати, скільки вже сплачено,
  - визначити стан: “неоплачено / частково / повністю / переплата”.
- стан “сплачено” не зберігається флагом — завжди рахується на льоту.


---

## 5. Організаційна структура

### 5.1. `org_units`

**Призначення:**  
Ієрархічна структура підприємства:

- підприємство
- департаменти
- управління
- відділи
- сектори
- тощо

Структура **довільної глибини** (дерево, не фіксована).

**Поля:**

- `id` — INTEGER, PK
- `parent_id` — INTEGER, FK → `org_units.id` (NULL для кореня)
- `code` — TEXT, внутрішній код підрозділу (унікальний серед активних)
- `name` — TEXT, назва підрозділу
- `unit_type` — TEXT (`COMPANY`, `DEPARTMENT`, `DIVISION`, `SECTION`, `TEAM`, …)
- `valid_from` — DATE
- `valid_to` — DATE, NULL = актуальний
- `created_at` — DATETIME
- `updated_at` — DATETIME

**Інваріанти:**

- структура — дерево, цикли заборонені.
- один підрозділ має одного батька (або NULL).
- підрозділ не видаляється фізично — тільки закривається `valid_to`.
- на одну дату не може існувати два активні підрозділи з однаковим `code`.


### 5.2. `employee_org_unit_history`

**Призначення:**  
Історія, до якого підрозділу належить працівник у різні періоди.

**Поля:**

- `id` — INTEGER, PK
- `employee_id` — INTEGER, FK → `employees.id`
- `org_unit_id` — INTEGER, FK → `org_units.id`
- `valid_from` — DATE, початок належності
- `valid_to` — DATE, кінець (NULL = актуально)
- `comment` — TEXT, примітка (наказ, підстава)

**Інваріанти:**

- на один момент часу працівник може належати не більше ніж одному підрозділу.
- переведення:
  - закриває попередній запис `valid_to`,
  - створює новий з новим `valid_from`.
- історія не редагується заднім числом.
- записи створюються/змінюються тільки через документи-накази.


---

## 6. Календар і зміни

### 6.1. `calendar_days`

**Призначення:**  
Фіксує для кожного календарного дня його статус:

- звичайний робочий
- вихідний
- офіційне свято
- перенесений робочий/вихідний
- скорочений передсвятковий день

**Поля:**

- `id` — INTEGER, PK
- `calendar_date` — DATE, унікальна дата
- `year` — INTEGER, рік (дубль для зручності)
- `is_weekend` — INTEGER (0/1), звичайний вихідний (сб/нд)
- `is_official_holiday` — INTEGER (0/1), офіційне свято
- `workday_type` — TEXT:
  - `REGULAR`
  - `SHORTENED`
  - `TRANSFERRED_WORKDAY`
  - `TRANSFERRED_DAY_OFF`
- `holiday_code` — TEXT, код свята (`NEW_YEAR`, `INDEPENDENCE_DAY`, …)
- `holiday_name` — TEXT, назва свята
- `created_at` — DATETIME
- `updated_at` — DATETIME

**Інваріанти:**

- по `calendar_date` — не більше одного запису.
- `is_official_holiday = 1` ⇒ день має статус свята (по правилах країни).
- розрахунок не хардкодить свята в коді, а завжди дивиться в `calendar_days`.


### 6.2. `shift_types`

**Призначення:**  
Опис типів змін для обліку робочого часу й розрахунку оплати.

**Поля:**

- `id` — INTEGER, PK
- `code` — TEXT, унікальний код (`DAY_8H`, `NIGHT_12H`, `24H_DUTY`, …)
- `name` — TEXT, назва (“Денна 8 год”, “Нічна 12 год”, …)
- `start_time` — TEXT (`HH:MM`), час початку
- `end_time` — TEXT (`HH:MM`), час завершення
- `planned_hours` — INTEGER, тривалість (у хвилинах або сотих години)
- `is_night_shift` — INTEGER (0/1)
- `comment` — TEXT
- `valid_from` — DATE
- `valid_to` — DATE, NULL = актуально
- `created_at` — DATETIME
- `updated_at` — DATETIME

**Інваріанти:**

- `code` унікальний серед активних.
- зміни версіонуються через `valid_from` / `valid_to`, старі записи не перетираються.


### 6.3. `shift_rules`

**Призначення:**  
Правила нарахування по змінах, з урахуванням календаря та обсягів.

**Поля:**

- `id` — INTEGER, PK
- `shift_type_id` — INTEGER, FK → `shift_types.id`
- `accrual_type_id` — INTEGER, FK → `accrual_types.id`
- `calendar_condition` — TEXT:
  - `ANY` — будь-який день
  - `WEEKEND` — вихідні
  - `HOLIDAY` — свята
  - `WORKDAY` — звичайні робочі
- `valid_from` — DATE
- `valid_to` — DATE, NULL = актуально
- `hour_multiplier` — REAL, множник на ставку (1.0, 1.5, 2.0 …)
- `volume_norm` — REAL, нормативний обсяг за зміну (для відрядної/об’ємної оплати)
- `over_volume_multiplier` — REAL, множник для понаднормових обсягів
- `flags_json` — TEXT (JSON), додаткові параметри
- `created_at` — DATETIME
- `updated_at` — DATETIME

**Інваріанти:**

- для одного `shift_type_id + accrual_type_id + calendar_condition` у межах періоду дії не має бути двох активних правил.
- логіка розрахунку по змінах опирається на `shift_rules`, а не на захардкожені коефіцієнти.


---

## 7. Робочий час

### 7.1. `work_day_records`

**Призначення:**  
Факт обліку робочого часу по працівнику і даті, який потім використовують для розрахунку зарплати.

**Поля:**

- `id` — INTEGER, PK
- `employee_id` — INTEGER, FK → `employees.id`
- `work_date` — DATE, календарна дата
- `shift_type_id` — INTEGER, FK → `shift_types.id` (опційно, якщо день прив’язаний до зміни)
- `work_hours` — INTEGER, звичайні години (мінорні одиниці: хвилини або соті)
- `overtime_hours` — INTEGER, понаднормові години
- `night_hours` — INTEGER, нічні години
- `weekend_hours` — INTEGER, години у вихідні/свята (якщо потрібно окремо)
- `absence_code` — TEXT, причина відсутності (`VACATION`, `SICK`, `UNPAID`, `BUSINESS_TRIP`, …) або NULL
- `source` — TEXT, джерело (`TIMESHEET`, `IMPORT`, `DOC`, …)
- `status` — TEXT, статус (`DRAFT`, `APPROVED`)
- `created_at` — DATETIME
- `updated_at` — DATETIME

**Інваріанти:**

- для комбінації (`employee_id`, `work_date`) існує не більше одного актуального запису.
- сума `work_hours + overtime_hours + night_hours + weekend_hours` не повинна логічно перевищувати 24 години.
- розрахунок зарплати використовує тільки записи зі `status = 'APPROVED'`.
- статус `APPROVED` виставляється не вручну, а через операцію/документ “затвердити табель”.


---

## 8. Системне

### 8.1. `schema_meta`

**Призначення:**  
Вказує, яку версію схеми БД зараз застосовано, щоб update-движок знав, які міграції ще треба виконати.

**Поля (мінімум):**

- `id` — INTEGER, PK, через `CHECK (id = 1)` можна зафіксувати один рядок
- `schema_version` — INTEGER, поточний номер версії схеми
- `updated_at` — DATETIME

**Альтернатива:**  
Таблиця `migrations`:

- `id`
- `name` (ім’я файлу міграції)
- `applied_at` — коли застосовано

Але логіка одна: **старі міграції не редагуються**, тільки додаються нові, а перед оновленням завжди робиться бекап БД.

### 7.2. `work_volume_records` — облік обсягів роботи

**Призначення:**  
Зберігає обсяги виконаної роботи, які використовуються при розрахунку відрядної оплати, оплати за кілометри та інших видів, де сума залежить від кількості/обсягу.

Ця таблиця є універсальною:
- для продукції (штуки, операції),
- для пробігу (кілометри),
- для інших обсягів (тонни, замовлення, тощо).

**Поля:**

- `id` — INTEGER, PK
- `employee_id` — INTEGER, FK → `employees.id`  
  Працівник, якому належить цей обсяг.

- `volume_date` — DATE  
  Дата, до якої відноситься обсяг (день виконання роботи / день закриття рейсу тощо).

- `volume_type` — TEXT  
  Код виду обсягу, наприклад:
  - `PRODUCT_PCS` — продукція, штуки
  - `KM_DRIVEN` — пробіг, кілометри
  - `ORDERS` — замовлення
  - інші коди за домовленістю.

- `quantity` — REAL або INTEGER  
  Кількість/обсяг (шт, км, тонни, умовні одиниці).  
  Конкретна одиниця фіксується в `unit_code`.

- `unit_code` — TEXT  
  Код одиниці виміру (`PCS`, `KM`, `TON`, `HOUR`, ...).

- `source` — TEXT  
  Джерело даних:
  - `IMPORT` — імпорт з зовнішньої системи,
  - `DOC` — проведений документ (наряд, маршрутний лист),
  - `MANUAL` — ручний ввід.

- `status` — TEXT  
  Статус запису:
  - `DRAFT` — чорновий, не використовується в розрахунках,
  - `APPROVED` — затверджений, може братися в розрахунок зарплати.

- `comment` — TEXT, опціонально  
  Додаткові пояснення (номер рейсу, наряд, маршрутна відомість, тощо).

- `created_at` — DATETIME  
- `updated_at` — DATETIME  

**Інваріанти / правила використання:**

- В розрахунках нарахувань з `calculation_mode = 'PIECE_VOLUME'` або `calculation_mode = 'DISTANCE_KM'`
  використовується **тільки** `work_volume_records` зі `status = 'APPROVED'`.

- Виправлення/зміни обсягів мають відбуватись через:
  - нові записи,
  - сторнування / коригуючі документи,
  а не “тихе” редагування існуючих затверджених рядків.

- `volume_type` + `unit_code` повинні бути узгоджені з правилами (опис в домені), щоб розрахунок однозначно знав,
  яку ставку і яку формулу застосовувати.

**Звязок з типами оплати праці:**

- Для `calculation_mode = 'PIECE_VOLUME'`:
  - по `volume_type` обирається потрібна розцінка з `employee_bases` (або іншого довідника),
  - `quantity` множиться на ставку.

- Для `calculation_mode = 'DISTANCE_KM'`:
  - сумується `quantity` по `volume_type = 'KM_DRIVEN'`,
  - результат множиться на `KM_RATE` з `employee_bases`.

