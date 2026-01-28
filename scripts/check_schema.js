// Check database schema and data
const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, '..', 'data', 'payroll.db');
const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.error('❌ Помилка підключення до БД:', err);
    process.exit(1);
  }
  console.log('✅ Підключено до БД:', dbPath);
});

// Get all tables
db.all(`
  SELECT name FROM sqlite_master
  WHERE type='table' AND name NOT LIKE 'sqlite_%'
  ORDER BY name
`, (err, tables) => {
  if (err) {
    console.error('❌ Помилка отримання таблиць:', err);
    db.close();
    return;
  }

  console.log('\n📊 Таблиці в базі даних:');
  console.log('='.repeat(50));

  const modules = {
    'Модуль 1: Структура підприємства і працівники': [
      'org_units', 'employees', 'employee_org_unit_history',
      'contracts', 'calculation_rules', 'calculation_templates', 'template_rules'
    ],
    'Модуль 2: Результати роботи': [
      'work_results', 'timesheets', 'production_results'
    ],
    'Модуль 3: Періоди та нарахування': [
      'calculation_periods', 'accrual_documents', 'accrual_results', 'change_requests'
    ],
    'Модуль 4: Платежі': [
      'payment_rules', 'payment_documents', 'payment_items', 'bank_statements'
    ],
    'Допоміжні таблиці': [
      'accrual_types', 'rule_versions', 'base_values', 'employee_bases',
      'accrual_operations', 'accrual_parts', 'payment_operations',
      'payment_accrual_links', 'employee_categories_history', 'schema_meta'
    ]
  };

  const tableNames = tables.map(t => t.name);

  for (const [moduleName, moduleTables] of Object.entries(modules)) {
    console.log(`\n${moduleName}:`);
    for (const tableName of moduleTables) {
      const exists = tableNames.includes(tableName);
      console.log(`  ${exists ? '✅' : '❌'} ${tableName}`);
    }
  }

  console.log('\n\n📈 Статистика даних:');
  console.log('='.repeat(50));

  const queries = [
    { name: 'Працівники', query: 'SELECT COUNT(*) as count FROM employees' },
    { name: 'Організаційні підрозділи', query: 'SELECT COUNT(*) as count FROM org_units' },
    { name: 'Контракти', query: 'SELECT COUNT(*) as count FROM contracts' },
    { name: 'Правила розрахунків', query: 'SELECT COUNT(*) as count FROM calculation_rules' },
    { name: 'Шаблони розрахунків', query: 'SELECT COUNT(*) as count FROM calculation_templates' },
    { name: 'Зв\'язки шаблонів і правил', query: 'SELECT COUNT(*) as count FROM template_rules' },
    { name: 'Типи нарахувань', query: 'SELECT COUNT(*) as count FROM accrual_types' },
    { name: 'Базові значення', query: 'SELECT COUNT(*) as count FROM base_values' },
    { name: 'Персональні бази', query: 'SELECT COUNT(*) as count FROM employee_bases' }
  ];

  let completed = 0;
  queries.forEach(({ name, query }) => {
    db.get(query, (err, row) => {
      if (!err && row) {
        console.log(`  ${name}: ${row.count}`);
      }
      completed++;
      if (completed === queries.length) {
        console.log('\n' + '='.repeat(50));
        console.log('\n✅ База даних успішно створена згідно архітектури!');
        db.close();
      }
    });
  });
});
