\# Міграція на Версію 2.0



\## Що Нового?



\### ✅ Дві Ієрархії

\- Дерево підприємства (organizational\_units)

\- Дерево груп (groups) - НОВЕ!



\### ✅ Позиції та Групи

\- position\_groups (many-to-many) - НОВЕ!

\- Працівник може бути в кількох групах

\- Історія належності до груп



\### ✅ Immutability Правил

\- Правила НЕ змінюються, а закриваються

\- valid\_from / valid\_until (TIMESTAMP)

\- replaces\_rule\_id для версійності



\### ✅ Точність До Хвилини

\- Всі DATE → TIMESTAMP WITH TIME ZONE

\- Табель з точним часом (work\_start, work\_end)

\- Автоматичне розбиття періодів



\### ✅ Графіки Змін

\- shift\_schedules (денні, нічні, вечірні)

\- position\_schedules (графік для позиції)

\- Надбавки за тип зміни



\### ✅ Таблиця Перегляду

\- Materialized View: accrual\_summary

\- Швидкий перегляд всіх нарахувань



---



\## 🚀 Швидкий Старт



\### Крок 1: Backup Поточної БД

```powershell

docker exec payroll\_postgres pg\_dump -U admin payroll > C:\\Work\\zarplata\\backup\_$(Get-Date -Format "yyyyMMdd\_HHmmss").sql

```



\### Крок 2: Виконати Міграцію

```powershell

\# Перейти в папку проекту

cd C:\\Work\\zarplata\\backend



\# Створити міграцію (файл вже готовий в alembic/versions/)

docker-compose exec backend alembic upgrade head

```



\### Крок 3: Перевірити

```powershell

docker exec -it payroll\_postgres psql -U admin -d payroll



\# В psql:

\\dt                           -- список таблиць

\\d groups                     -- структура groups

\\d position\_groups            -- нова таблиця

\\d+ accrual\_summary          -- materialized view



\# Перевірити parent\_id

SELECT id, code, name, parent\_id, level FROM groups;



\# Вийти

\\q

```



\### Крок 4: Додати Тестові Дані (опціонально)

```powershell

\# Групи

docker cp seed-data/01-groups-hierarchy.sql payroll\_postgres:/tmp/

docker exec -it payroll\_postgres psql -U admin -d payroll -f /tmp/01-groups-hierarchy.sql



\# Прив'язка позицій до груп

docker cp seed-data/02-position-groups.sql payroll\_postgres:/tmp/

docker exec -it payroll\_postgres psql -U admin -d payroll -f /tmp/02-position-groups.sql



\# Правила для груп

docker cp seed-data/03-rules-for-groups.sql payroll\_postgres:/tmp/

docker exec -it payroll\_postgres psql -U admin -d payroll -f /tmp/03-rules-for-groups.sql

```



---



\## 📊 Перевірка Міграції



\### Таблиці що ДОДАЛИСЬ:

\- ✅ position\_groups

\- ✅ shift\_schedules

\- ✅ position\_schedules

\- ✅ split\_reasons

\- ✅ accrual\_summary (materialized view)



\### Поля що ДОДАЛИСЬ:

\- ✅ groups.parent\_id, groups.level

\- ✅ calculation\_rules.group\_id

\- ✅ calculation\_rules.valid\_from/until (TIMESTAMP)

\- ✅ calculation\_rules.replaces\_rule\_id

\- ✅ calculation\_periods.start\_datetime/end\_datetime (TIMESTAMP)

\- ✅ calculation\_periods.split\_reason, parent\_period\_id

\- ✅ timesheets.work\_start/end (TIMESTAMP)

\- ✅ contracts.start\_datetime/end\_datetime (TIMESTAMP)

\- ✅ accrual\_results.rule\_source\_type/id



---



\## 🔧 Якщо Щось Пішло Не Так



\### Відкат Міграції:

```powershell

docker-compose exec backend alembic downgrade -1

```



\### Відновлення з Backup:

```powershell

docker exec -i payroll\_postgres psql -U admin payroll < C:\\Work\\zarplata\\backup\_20250130\_153000.sql

```



---



\## 📚 Документація



\- `docs/database/schema-full.sql` - повна SQL схема

\- `docs/database/erd.md` - ER діаграма

\- `docs/database/dependencies.md` - залежності таблиць

\- `docs/architecture/concepts.md` - концепція системи



---



\## ✅ Наступні Кроки



1\. Оновити SQLAlchemy models

2\. Додати API для груп

3\. Додати логіку пошуку правил

4\. Додати логіку розбиття періодів

5\. Оновити Frontend



---



\*\*Успішної Міграції!\*\* 🎉

