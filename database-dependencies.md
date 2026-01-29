\# Залежності Таблиць



\## Дерева (Самопосилання)



1\. \*\*organizational\_units\*\* → parent\_id → organizational\_units

2\. \*\*groups\*\* → parent\_id → groups

3\. \*\*calculation\_periods\*\* → parent\_period\_id → calculation\_periods

4\. \*\*calculation\_rules\*\* → replaces\_rule\_id → calculation\_rules



\## Основні Зв'язки



\### Працівники → Позиції

employees (1) → (N) positions



\### Позиції → Підрозділи

positions (N) → (1) organizational\_units



\### Позиції → Групи (Many-to-Many)

positions (N) ← position\_groups → (N) groups



\### Позиції → Контракти

positions (1) → (N) contracts



\### Позиції → Графіки (через position\_schedules)

positions (N) ← position\_schedules → (N) shift\_schedules



\### Позиції → Табель

positions (1) → (N) timesheets



\### Правила → Scope (ONE OF)

calculation\_rules → positions (0..1)

calculation\_rules → organizational\_units (0..1)

calculation\_rules → groups (0..1)

(якщо всі NULL → глобальне)



\### Шаблони → Правила

calculation\_templates (1) → (N) template\_rules

template\_rules → rule\_code (не FK!)



\### Періоди → Документи

calculation\_periods (1) → (N) accrual\_documents



\### Документи → Результати

accrual\_documents (1) → (N) accrual\_results



\### Результати → Всі Сутності

accrual\_results → position

accrual\_results → employee (денормалізація)

accrual\_results → organizational\_unit (денормалізація)

accrual\_results → calculation\_rule



\## Порядок Створення (для міграції)



1\. organizational\_units (з parent\_id = NULL для root)

2\. groups (з parent\_id = NULL для root)

3\. employees

4\. positions

5\. position\_groups

6\. contracts

7\. shift\_schedules

8\. position\_schedules

9\. timesheets

10\. calculation\_rules

11\. calculation\_templates

12\. template\_rules

13\. calculation\_periods

14\. accrual\_documents

15\. accrual\_results

16\. split\_reasons (довідник)



\## Порядок Видалення (для очищення)



Зворотній порядок!

