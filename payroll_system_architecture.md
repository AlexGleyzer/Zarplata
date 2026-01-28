# Система Управління Розрахунками Заробітної Плати

## Technology Stack

- **Database:** PostgreSQL
- **Backend:** Python + FastAPI + SQLAlchemy 2.0
- **Migrations:** Alembic
- **Frontend:** React
- **Containerization:** Docker

## Загальна Архітектура

Система складається з чотирьох основних модулів, які працюють послідовно:

```
Структура/Працівники → Результати → Періоди/Нарахування → Платежі
```

---

## Модуль 1: Структура Підприємства і Працівники

### Призначення
- Зберігання організаційної ієрархії
- Управління даними працівників
- Визначення правил нарахувань
- Створення шаблонів розрахунків

### Основні Таблиці

#### 1.1 `organizational_units` - Організаційна структура
```sql
- id (PK)
- parent_id (FK to organizational_units) -- для ієрархії
- code -- унікальний код підрозділу
- name -- назва
- level -- рівень в ієрархії (1-6)
- is_active -- активний/неактивний
- created_at
- updated_at
```

#### 1.2 `employees` - Працівники
```sql
- id (PK)
- organizational_unit_id (FK)
- personnel_number -- табельний номер
- first_name
- last_name
- middle_name
- hire_date
- termination_date (nullable)
- is_active
- created_at
- updated_at
```

#### 1.3 `contracts` - Контракти працівників
```sql
- id (PK)
- employee_id (FK)
- contract_number
- contract_type -- (hourly, salary, piecework, task_based)
- start_date
- end_date (nullable)
- base_rate -- базова ставка
- currency
- organizational_unit_id (FK) -- до якого підрозділу відноситься
- is_active
- created_at
- updated_at
```

#### 1.4 `calculation_rules` - Правила нарахувань
```sql
- id (PK)
- organizational_unit_id (FK, nullable) -- якщо NULL = глобальне правило
- code -- унікальний код правила
- name -- назва правила
- description
- sql_code -- TEXT, SQL код для виконання
- rule_type -- (accrual, deduction, tax)
- is_active
- created_at
- updated_at
- created_by -- користувач який створив
```

**Принцип успадкування правил:**
- Система шукає правило на рівні конкретного підрозділу
- Якщо не знайдено → йде на рівень вище по ієрархії
- Продовжує до кореневого рівня

#### 1.5 `calculation_templates` - Шаблони розрахунків
```sql
- id (PK)
- code -- унікальний код шаблону
- name -- назва (наприклад "Місячна зарплата")
- description
- is_active
- created_at
- updated_at
```

#### 1.6 `template_rules` - Зв'язок шаблонів і правил
```sql
- id (PK)
- template_id (FK)
- rule_id (FK)
- execution_order -- порядок виконання (1, 2, 3...)
- is_active
```

**Важливо:** Правила виконуються послідовно згідно `execution_order`. Кожне наступне правило бачить результати попередніх.

---

## Модуль 2: Результати Роботи

### Призначення
Фіксація фактичних результатів роботи працівників (табель, виробництво тощо)

### Основні Таблиці

#### 2.1 `work_results` - Результати роботи
```sql
- id (PK)
- employee_id (FK)
- result_date -- дата фіксації результату
- result_type -- (hours, minutes, pieces, tasks, shifts)
- value -- числове значення
- unit -- одиниця виміру
- organizational_unit_id (FK)
- status -- (draft, confirmed, cancelled)
- created_at
- updated_at
- created_by
```

#### 2.2 `timesheets` - Табель обліку робочого часу
```sql
- id (PK)
- employee_id (FK)
- work_date
- hours_worked
- minutes_worked
- shift_type -- (day, night, overtime)
- organizational_unit_id (FK)
- status
- created_at
- updated_at
```

#### 2.3 `production_results` - Результати виробництва
```sql
- id (PK)
- employee_id (FK)
- work_date
- product_code -- код продукції/завдання
- quantity -- кількість
- quality_coefficient -- коефіцієнт якості
- organizational_unit_id (FK)
- status
- created_at
- updated_at
```

---

## Модуль 3: Періоди та Нарахування

### Призначення
- Створення розрахункових періодів
- Виконання нарахувань згідно шаблонів і правил
- Управління статусами документів
- Історія всіх змін

### Основні Таблиці

#### 3.1 `calculation_periods` - Розрахункові періоди
```sql
- id (PK)
- period_code -- унікальний код (наприклад "2024-01")
- period_name
- start_date
- end_date
- period_type -- (monthly, weekly, custom)
- organizational_unit_id (FK, nullable) -- null = вся компанія
- employee_id (FK, nullable) -- null = всі працівники
- status -- (draft, in_review, approved, cancelled)
- created_at
- updated_at
- created_by
```

#### 3.2 `accrual_documents` - Документи нарахувань
```sql
- id (PK)
- document_number -- номер документа
- period_id (FK)
- template_id (FK) -- який шаблон використано
- organizational_unit_id (FK, nullable)
- employee_id (FK, nullable)
- status -- (draft, in_review, approved, cancelled)
- calculation_date -- коли виконано розрахунок
- approved_date (nullable)
- approved_by (nullable)
- cancelled_date (nullable)
- cancelled_by (nullable)
- created_at
- updated_at
- created_by
```

#### 3.3 `accrual_results` - Результати нарахувань
```sql
- id (PK)
- document_id (FK)
- employee_id (FK)
- rule_id (FK) -- яке правило застосовано
- rule_code -- код правила (для історії)
- amount -- сума
- calculation_base -- база розрахунку (якщо є)
- currency
- status -- (active, cancelled)
- created_at
```

**Важливо:** Результати ніколи не видаляються і не редагуються, тільки міняється статус.

#### 3.4 `change_requests` - Запити на зміни
```sql
- id (PK)
- request_number
- document_id (FK) -- який документ треба змінити
- reason -- причина зміни
- requested_by
- request_date
- status -- (pending, approved, rejected)
- approved_by (nullable)
- approved_date (nullable)
- created_at
- updated_at
```

**Workflow змін:**
1. Створюється запит на зміну
2. Запит йде на затвердження
3. При затвердженні:
   - Старий документ → status = 'cancelled'
   - Всі його результати → status = 'cancelled'
   - Створюється новий документ з коректними даними

---

## Модуль 4: Платежі

### Призначення
- Формування платіжних документів на основі нарахувань
- Групування платежів згідно правил
- Workflow затвердження платежів
- Інтеграція з банками

### Основні Таблиці

#### 4.1 `payment_rules` - Правила формування платежів
```sql
- id (PK)
- code -- унікальний код
- name -- назва правила
- description
- rule_type -- (individual, grouped, bank_statement)
- grouping_logic -- JSON з логікою групування
- recipient_type -- (employee_card, tax_authority, bank_special)
- is_active
- created_at
- updated_at
```

**Приклади правил:**
- Зарплата на картки → individual, recipient_type = employee_card
- Податки → grouped, recipient_type = tax_authority
- Зарплата через банк → grouped, recipient_type = bank_special (+ відомість)

#### 4.2 `payment_documents` - Документи платежів
```sql
- id (PK)
- document_number
- period_id (FK)
- payment_rule_id (FK) -- яке правило застосовано
- organizational_unit_id (FK, nullable)
- employee_id (FK, nullable)
- total_amount
- currency
- payment_date (nullable) -- планована дата
- actual_payment_date (nullable) -- фактична дата
- status -- (draft, in_review, approved, executed, cancelled)
- created_at
- updated_at
- created_by
- approved_by (nullable)
- executed_by (nullable)
```

#### 4.3 `payment_items` - Позиції платежів
```sql
- id (PK)
- payment_document_id (FK)
- accrual_result_id (FK) -- зв'язок з нарахуванням
- employee_id (FK)
- amount
- currency
- recipient_account -- рахунок одержувача
- purpose -- призначення платежу
- status -- (pending, executed, cancelled)
```

#### 4.4 `bank_statements` - Банківські відомості
```sql
- id (PK)
- payment_document_id (FK)
- statement_number
- file_path -- шлях до згенерованого файлу (Excel/PDF)
- bank_code
- created_at
```

---

## Зв'язки між Модулями

### Потік даних:

```
1. Структура/Працівники
   ↓ (містить правила і шаблони)
   
2. Результати Роботи
   ↓ (факт відпрацьованого)
   
3. Періоди/Нарахування
   - Створюється період
   - Вибирається шаблон
   - Виконуються правила послідовно
   - Кожне правило бачить результати попередніх
   ↓ (утворюються нарахування)
   
4. Платежі
   - Вибираються проведені нарахування
   - Застосовуються правила платежів
   - Формуються платіжні документи
```

---

## Ключові Принципи Системи

### 1. Immutability (Незмінність даних)
- Ніщо не видаляється і не редагується
- Тільки додавання нових записів
- Зміни через створення нового документа і скасування старого
- Повна історія всіх операцій

### 2. Workflow і Статуси
Всі документи проходять через статуси:
- `draft` → можна редагувати/перераховувати
- `in_review` → на розгляді
- `approved` → затверджено, зафіксовано
- `cancelled` → скасовано (при коригуваннях)

### 3. Ієрархія і Успадкування
- Правила прив'язані до рівнів структури
- Якщо правила немає на рівні → береться з верхнього
- До кореневого рівня

### 4. Послідовне Виконання
- Правила в шаблоні виконуються по черзі
- Кожне правило бачить результати попередніх
- Порядок критичний

### 5. Аудит і Прозорість
- Всі зміни логуються (created_by, updated_by)
- Скасовані документи видимі в інтерфейсі
- Повна історія для аналізу

---

## Перший Етап Розробки (MVP)

### База даних
1. Створити всі таблиці в PostgreSQL
2. Додати тестові дані:
   - Структура: 1 компанія → 2 відділи → 5 працівників
   - 2-3 прості правила (основна зарплата, податок)
   - 1 шаблон з цими правилами

### Backend (FastAPI)
1. Базові CRUD endpoints для всіх сутностей
2. Endpoint для виконання розрахунку
3. Міграції через Alembic

### Frontend (React)
1. **Текстове поле з чіпами** для команд:
   - "створити період січень для відділу продажів"
   - "створити період лютий для працівника Іванов"
   - Парсинг команд → виклик API
   
2. Перегляд таблиць:
   - Список періодів
   - Список нарахувань
   - Деталі розрахунку

### Тестовий сценарій
1. Створити період через текстове поле
2. Вибрати шаблон
3. Запустити розрахунок
4. Переглянути результати в таблиці

---

## Наступні Кроки

1. **Розширення правил:**
   - Складніші SQL запити
   - Умовна логіка
   - Коефіцієнти та надбавки

2. **Workflow:**
   - Затвердження документів
   - Запити на зміни
   - Ролі та права доступу

3. **Модуль платежів:**
   - Правила групування
   - Генерація банківських відомостей
   - Інтеграція з банк-клієнтом

4. **UI покращення:**
   - Візуалізація структури підприємства
   - Dashboard з аналітикою
   - Експорт звітів

---

## Технічні Деталі

### Міграції (Alembic)
```bash
# Ініціалізація
alembic init alembic

# Створення міграції
alembic revision --autogenerate -m "Initial tables"

# Застосування
alembic upgrade head
```

### Docker Compose
```yaml
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: payroll
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: secure_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  backend:
    build: ./backend
    ports:
      - "8000:8000"
    depends_on:
      - postgres

  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    depends_on:
      - backend
```

### Структура проекту
```
payroll-system/
├── backend/
│   ├── alembic/
│   ├── app/
│   │   ├── models/
│   │   ├── schemas/
│   │   ├── api/
│   │   ├── core/
│   │   └── services/
│   ├── requirements.txt
│   └── Dockerfile
├── frontend/
│   ├── src/
│   │   ├── components/
│   │   ├── pages/
│   │   ├── services/
│   │   └── App.jsx
│   ├── package.json
│   └── Dockerfile
├── docker-compose.yml
└── README.md
```

---

## Безпека

### SQL Injection
- Всі SQL правила виконуються через prepared statements
- Параметри передаються окремо від коду
- Валідація перед виконанням

### Права доступу
- Таблиця ролей (додати пізніше)
- Обмеження на створення/зміну правил
- Аудит всіх операцій

### Шифрування
- Паролі користувачів (bcrypt)
- Чутливі дані в БД (при необхідності)
- HTTPS для API

---

## Висновок

Система спроектована з урахуванням:
- ✅ Масштабованості (від малого бізнесу до великих підприємств)
- ✅ Гнучкості (правила і шаблони налаштовуються)
- ✅ Прозорості (повна історія всіх операцій)
- ✅ Надійності (immutable архітектура)
- ✅ Безпеки (workflow затвердження, аудит)

Готова до поетапної імплементації та тестування.
