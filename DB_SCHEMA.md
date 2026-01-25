0. Загальна картинка

Таблиці:

Працівники й їхні стани

employees

employee_categories_history (категорії/пільги по періодах)

Типи і правила розрахунків

accrual_types — типи нарахувань/утримань

rule_versions — версії правил по типах

base_values — базові величини (мінімалка, прожитковий, тощо)

employee_bases (опційно, для окладів/ставок по працівнику)

Нарахування

accrual_operations — “логічна” операція нарахування (борг)

accrual_parts — розбиття на підперіоди

Виплати

payment_operations — факт виплати (платіж)

payment_accrual_links — зв’язок виплати з нарахуваннями (частково/повністю)

Системне

schema_meta — версія схеми / службова інфа

1. Працівники
1.1. employees

Хто взагалі існує в системі.

Поля (концептуально):

id — PK

code — внутрішній код / табельний (унікальний)

full_name — ПІБ

tax_id — ІПН (якщо захочеш)

hired_at — дата прийому

fired_at — дата звільнення (NULL, якщо працює)

created_at, updated_at — службові

Сенс:
на будь-яку дату ми можемо сказати, працівник “активний” чи ні (по hired_at / fired_at).

1.2. employee_categories_history

Категорії працівника по часу (інвалідність, неповнолітній, пільги і т.д.)

Поля:

id — PK

employee_id — FK → employees.id

category_code — тип категорії (наприклад: DISABLED_GROUP_1, MINOR, FULL_TIME, PART_TIME тощо)

valid_from — дата початку дії

valid_to — дата кінця дії (NULL = діє дотепер)

comment — опціонально

Сенс:
коли ми рахуємо за період, можемо подивитись, яка категорія діє на конкретну дату, і, відповідно, яке правило брати.

2. Типи і правила розрахунків
2.1. accrual_types

ЩО ми нараховуємо / утримуємо.

Поля:

id — PK

code — короткий код (унікальний): SALARY, PIT, WAR_TAX, ESV_EMPLOYER, SICK, MATERNITY…

name — людська назва (“Основна зарплата”, “ПДФО”, …)

direction — INCOME / WITHHOLDING / EMPLOYER_CONTRIBUTION

category — умовна група: WAGE, TAX, COMPENSATION, BENEFIT, etc

is_active — флажок, щоб не видаляти фізично

Сенс:
усі операції нарахувань/утримань посилаються на accrual_types.

2.2. rule_versions

Конкретні правила розрахунку в часі.

Поля:

id — PK

accrual_type_id — FK → accrual_types.id

valid_from — дата початку дії правила (включно)

valid_to — дата закінчення (NULL = діє дотепер)

base_kind — від чого рахуємо:

напр. GROSS_WAGE, AVG_DAILY, MIN_WAGE, TAXABLE_BASE, etc

human_description — опис словами, як для бухгалтера

formula_dsl — машинне представлення формули (рядок, який інтерпретує ядро)

flags_json — опціональне поле (JSON), типу:

{"enters_pit_base": true, "enters_esv_base": false, ...}

Сенс:
для будь-якої дати і типу ми знаходимо активну rule_version і по ній рахуємо.

2.3. base_values

Загальні базові величини (законодавчі: мін.ЗП, прожитковий, бази для ЄСВ, тощо).

Поля:

id — PK

base_code — код бази:

MIN_WAGE, LIVING_MINIMUM, ESV_MAX_BASE, etc

value — значення (я б тримав у копійках як INTEGER, але це вже реалізація)

valid_from, valid_to — період дії

comment

2.4. employee_bases (опційно, але логічно)

Персональні бази: оклад, погодинна ставка тощо.

Поля:

id — PK

employee_id — FK → employees.id

base_code — що це:

MONTHLY_SALARY, HOURLY_RATE, etc

value — розмір

valid_from, valid_to — період дії

3. Нарахування (борг)
3.1. accrual_operations

Логічна операція нарахування / утримання за період.

Поля:

id — PK

operation_code — унікальний код операції (щоб по ньому лінкувати виплати)

employee_id — FK → employees.id

accrual_type_id — FK → accrual_types.id

rule_version_id — FK → rule_versions.id (за яким правилом рахували)

period_from, period_to — період, за який це нарахування стосується (логічний)

total_amount — загальна сума нарахування (сума частин)

created_at

created_by — користувач/джерело

Сенс:
це “одна історія боргу” — потім по ній будуть виплати.

3.2. accrual_parts

Розбиття однієї операції на підперіоди, коли змінюються база/правила.

Поля:

id — PK

accrual_operation_id — FK → accrual_operations.id

part_from, part_to — підперіод

base_snapshot_json — збережений “зріз” баз:

оклад, ставки, коефіцієнти, категорія на цей період

amount — сума за цей підперіод

calc_details_json — деталі розрахунку (опційно: годин/днів, формула, проміжні значення)

Сенс:
якщо в середині періоду змінився оклад/закон/категорія — з’являється новий рядок в accrual_parts.
total_amount в основній операції = сума усіх amount тут.

4. Виплати
4.1. payment_operations

Факт, що гроші кудись пішли.

Поля:

id — PK

payment_code — номер/код платіжки/операції

payment_date

total_amount

recipient_type — EMPLOYEE / BUDGET / FUND (опціонально)

recipient_employee_id — FK → employees.id (якщо це виплата працівнику)

note

created_at, created_by

4.2. payment_accrual_links

Зв’язок між платежем і нарахуванням (бо один платіж може гасити кілька нарахувань і навпаки).

Поля:

id — PK

payment_id — FK → payment_operations.id

accrual_operation_id — FK → accrual_operations.id

amount — скільки з цього платежу пішло на цю операцію

Сенс:
по цій таблиці ми:

рахуємо, скільки сплачено по кожному нарахуванню

розуміємо, що частково/повністю/переплата

Стан “сплачено” не зберігаємо флагом — завжди рахуємо.

5. Системне
5.1. schema_meta

Щоб твій update-движок знав, де він.

Поля (мінімум):

id — PK або просто один рядок

schema_version — integer

updated_at

Або навіть простіше — таблиця migrations з:

id

name (файл міграції)

applied_at

Це у тебе вже по суті є логічно через runner — просто формалізуєш у миграції.

6. Що важливо: ми ще не чіпались до “сторнування” / коригувань

На цьому рівні ми:

можемо робити початкові нарахування

розбивати їх на підперіоди

прив’язувати виплати

дивитися борги

Пізніше можна додати:

таблицю adjustments або corrections
(коли треба сторнувати / донарахувати окремою операцією)

Але для першої версії схеми того, що накинули вище, більш ніж достатньо.