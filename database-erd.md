erDiagram

&nbsp;   %% ========== ОРГАНІЗАЦІЙНА СТРУКТУРА ==========

&nbsp;   organizational\_units ||--o{ organizational\_units : "parent\_id"

&nbsp;   organizational\_units ||--o{ positions : "має"

&nbsp;   organizational\_units ||--o{ calculation\_rules : "має правила"

&nbsp;   organizational\_units ||--o{ calculation\_periods : "для"

&nbsp;   organizational\_units ||--o{ accrual\_documents : "для"

&nbsp;   

&nbsp;   %% ========== ГРУПИ ==========

&nbsp;   groups ||--o{ groups : "parent\_id"

&nbsp;   groups ||--o{ position\_groups : "має позиції"

&nbsp;   groups ||--o{ calculation\_rules : "має правила"

&nbsp;   

&nbsp;   %% ========== ПРАЦІВНИКИ ТА ПОЗИЦІЇ ==========

&nbsp;   employees ||--o{ positions : "має позиції"

&nbsp;   employees ||--o{ calculation\_periods : "для"

&nbsp;   employees ||--o{ accrual\_results : "має нарахування"

&nbsp;   

&nbsp;   positions ||--o{ position\_groups : "належить до груп"

&nbsp;   positions ||--o{ contracts : "має контракти"

&nbsp;   positions ||--o{ position\_schedules : "має графіки"

&nbsp;   positions ||--o{ timesheets : "має табель"

&nbsp;   positions ||--o{ calculation\_rules : "має правила"

&nbsp;   positions ||--o{ accrual\_results : "має нарахування"

&nbsp;   

&nbsp;   position\_groups }o--|| groups : "група"

&nbsp;   position\_groups }o--|| positions : "позиція"

&nbsp;   

&nbsp;   %% ========== КОНТРАКТИ ==========

&nbsp;   contracts }o--|| positions : "для позиції"

&nbsp;   

&nbsp;   %% ========== ГРАФІКИ ==========

&nbsp;   shift\_schedules ||--o{ position\_schedules : "використовується в"

&nbsp;   position\_schedules }o--|| positions : "для позиції"

&nbsp;   

&nbsp;   %% ========== ТАБЕЛЬ ==========

&nbsp;   timesheets }o--|| positions : "для позиції"

&nbsp;   

&nbsp;   %% ========== ПРАВИЛА ==========

&nbsp;   calculation\_rules }o--o| positions : "для позиції"

&nbsp;   calculation\_rules }o--o| organizational\_units : "для підрозділу"

&nbsp;   calculation\_rules }o--o| groups : "для групи"

&nbsp;   calculation\_rules }o--o| calculation\_rules : "замінює"

&nbsp;   

&nbsp;   calculation\_templates ||--o{ template\_rules : "містить правила"

&nbsp;   template\_rules }o--|| calculation\_rules : "посилається на код"

&nbsp;   

&nbsp;   %% ========== ПЕРІОДИ ==========

&nbsp;   calculation\_periods }o--o| organizational\_units : "для"

&nbsp;   calculation\_periods }o--o| employees : "для"

&nbsp;   calculation\_periods ||--o{ calculation\_periods : "parent\_period\_id"

&nbsp;   calculation\_periods ||--o{ accrual\_documents : "має документи"

&nbsp;   

&nbsp;   %% ========== ДОКУМЕНТИ ==========

&nbsp;   accrual\_documents }o--|| calculation\_periods : "за період"

&nbsp;   accrual\_documents }o--|| calculation\_templates : "за шаблоном"

&nbsp;   accrual\_documents }o--o| organizational\_units : "для підрозділу"

&nbsp;   accrual\_documents ||--o{ accrual\_results : "містить результати"

&nbsp;   

&nbsp;   %% ========== РЕЗУЛЬТАТИ ==========

&nbsp;   accrual\_results }o--|| accrual\_documents : "в документі"

&nbsp;   accrual\_results }o--|| positions : "для позиції"

&nbsp;   accrual\_results }o--|| employees : "для працівника"

&nbsp;   accrual\_results }o--|| organizational\_units : "для підрозділу"

&nbsp;   accrual\_results }o--|| calculation\_rules : "по правилу"

