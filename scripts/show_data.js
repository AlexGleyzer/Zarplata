// Show detailed data from database
const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, '..', 'data', 'payroll.db');
const db = new sqlite3.Database(dbPath);

console.log('📋 Детальна інформація про дані в базі\n');
console.log('='.repeat(70));

// Show contracts
console.log('\n💼 КОНТРАКТИ:');
console.log('-'.repeat(70));
db.all(`
  SELECT
    c.contract_number,
    e.code as employee_code,
    e.full_name,
    c.contract_type,
    c.base_rate / 100.0 as rate,
    ou.name as org_unit
  FROM contracts c
  JOIN employees e ON c.employee_id = e.id
  LEFT JOIN org_units ou ON c.organizational_unit_id = ou.id
  ORDER BY c.id
`, (err, rows) => {
  if (!err && rows) {
    rows.forEach(r => {
      const rateStr = r.contract_type === 'salary'
        ? `${r.rate.toFixed(2)} грн/міс`
        : `${r.rate.toFixed(2)} грн/год`;
      console.log(`  ${r.contract_number} | ${r.employee_code} ${r.full_name}`);
      console.log(`    Тип: ${r.contract_type} | Ставка: ${rateStr}`);
      console.log(`    Підрозділ: ${r.org_unit}`);
      console.log();
    });
  }
});

// Show calculation rules
setTimeout(() => {
  console.log('\n📐 ПРАВИЛА РОЗРАХУНКІВ:');
  console.log('-'.repeat(70));
  db.all(`
    SELECT code, name, rule_type, description
    FROM calculation_rules
    ORDER BY id
  `, (err, rows) => {
    if (!err && rows) {
      rows.forEach(r => {
        console.log(`  ${r.code} - ${r.name}`);
        console.log(`    Тип: ${r.rule_type}`);
        console.log(`    ${r.description}`);
        console.log();
      });
    }
  });
}, 100);

// Show calculation template
setTimeout(() => {
  console.log('\n📋 ШАБЛОН РОЗРАХУНКІВ:');
  console.log('-'.repeat(70));
  db.all(`
    SELECT
      ct.code,
      ct.name,
      ct.description
    FROM calculation_templates ct
  `, (err, rows) => {
    if (!err && rows) {
      rows.forEach(r => {
        console.log(`  ${r.code} - ${r.name}`);
        console.log(`    ${r.description}`);
        console.log();

        // Show rules in template
        db.all(`
          SELECT
            cr.code,
            cr.name,
            tr.execution_order
          FROM template_rules tr
          JOIN calculation_rules cr ON tr.rule_id = cr.id
          JOIN calculation_templates ct ON tr.template_id = ct.id
          WHERE ct.code = ?
          ORDER BY tr.execution_order
        `, [r.code], (err2, rules) => {
          if (!err2 && rules) {
            console.log(`    Правила (порядок виконання):`);
            rules.forEach(rule => {
              console.log(`      ${rule.execution_order}. ${rule.code} - ${rule.name}`);
            });
            console.log();
          }
        });
      });
    }
  });
}, 200);

// Show organizational structure
setTimeout(() => {
  console.log('\n🏢 ОРГАНІЗАЦІЙНА СТРУКТУРА:');
  console.log('-'.repeat(70));
  db.all(`
    SELECT
      id,
      parent_id,
      code,
      name,
      unit_type
    FROM org_units
    WHERE parent_id IS NULL
    ORDER BY id
  `, (err, roots) => {
    if (!err && roots) {
      roots.forEach(root => {
        console.log(`  ${root.name} (${root.unit_type})`);

        // Show departments
        db.all(`
          SELECT id, code, name, unit_type
          FROM org_units
          WHERE parent_id = ?
          ORDER BY id
        `, [root.id], (err2, depts) => {
          if (!err2 && depts) {
            depts.forEach(dept => {
              console.log(`    └─ ${dept.name} (${dept.unit_type})`);

              // Show teams
              db.all(`
                SELECT id, code, name, unit_type
                FROM org_units
                WHERE parent_id = ?
                ORDER BY id
              `, [dept.id], (err3, teams) => {
                if (!err3 && teams) {
                  teams.forEach(team => {
                    // Count employees
                    db.get(`
                      SELECT COUNT(*) as count
                      FROM employee_org_unit_history
                      WHERE org_unit_id = ? AND valid_to IS NULL
                    `, [team.id], (err4, count) => {
                      if (!err4 && count) {
                        console.log(`       └─ ${team.name} (${count.count} працівників)`);
                      }
                    });
                  });
                }
              });
            });
          }
        });
      });
    }
  });
}, 300);

// Show base values
setTimeout(() => {
  console.log('\n\n💰 БАЗОВІ ЗНАЧЕННЯ:');
  console.log('-'.repeat(70));
  db.all(`
    SELECT base_code, value / 100.0 as value, valid_from, comment
    FROM base_values
    ORDER BY base_code
  `, (err, rows) => {
    if (!err && rows) {
      rows.forEach(r => {
        console.log(`  ${r.base_code}: ${r.value.toFixed(2)} грн`);
        console.log(`    ${r.comment}`);
        console.log();
      });
    }
  });
}, 400);

setTimeout(() => {
  console.log('\n' + '='.repeat(70));
  console.log('✅ База даних готова до використання!');
  console.log('\nНаступні кроки:');
  console.log('  1. Створити розрахунковий період');
  console.log('  2. Вибрати шаблон (MONTHLY_SALARY)');
  console.log('  3. Запустити розрахунок');
  console.log('  4. Переглянути результати');
  db.close();
}, 600);
