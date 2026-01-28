#!/usr/bin/env node
const Database = require('better-sqlite3');
const path = require('path');

const DB_PATH = path.join(__dirname, '..', 'data', 'payroll.db');

console.log('📊 Zarplata Database - Data Overview\n');
console.log('═'.repeat(70));

const db = new Database(DB_PATH, { readonly: true });

// ============== EMPLOYEES ==============
console.log('\n👥 EMPLOYEES:\n');
const employees = db.prepare(`
  SELECT e.employee_code, e.first_name || ' ' || e.last_name as name,
         c.contract_type, c.base_amount, e.status
  FROM employees e
  LEFT JOIN contracts c ON c.employee_id = e.id AND c.status = 'active'
  ORDER BY e.employee_code
`).all();

console.log('  Code     | Name            | Type    | Base Amount | Status');
console.log('  ' + '-'.repeat(65));
for (const emp of employees) {
  const type = (emp.contract_type || '-').padEnd(7);
  const amount = emp.base_amount ? emp.base_amount.toLocaleString('uk-UA') + ' ₴' : '-';
  console.log(`  ${emp.employee_code} | ${emp.name.padEnd(15)} | ${type} | ${amount.padStart(11)} | ${emp.status}`);
}

// ============== ORGANIZATIONAL STRUCTURE ==============
console.log('\n\n🏢 ORGANIZATIONAL STRUCTURE:\n');
const orgUnits = db.prepare(`
  WITH RECURSIVE tree AS (
    SELECT id, code, name, unit_type, parent_id, 0 as level
    FROM org_units WHERE parent_id IS NULL
    UNION ALL
    SELECT o.id, o.code, o.name, o.unit_type, o.parent_id, t.level + 1
    FROM org_units o JOIN tree t ON o.parent_id = t.id
  )
  SELECT * FROM tree ORDER BY level, name
`).all();

for (const unit of orgUnits) {
  const indent = '  '.repeat(unit.level + 1);
  const icon = unit.unit_type === 'company' ? '🏛️' : unit.unit_type === 'department' ? '📁' : '👥';
  console.log(`${indent}${icon} ${unit.name} (${unit.code})`);

  // Show employees in this unit
  const unitEmployees = db.prepare(`
    SELECT e.first_name || ' ' || e.last_name as name, h.position
    FROM employee_org_unit_history h
    JOIN employees e ON e.id = h.employee_id
    WHERE h.org_unit_id = ? AND h.end_date IS NULL
  `).all(unit.id);

  for (const emp of unitEmployees) {
    console.log(`${indent}   └─ ${emp.name} (${emp.position})`);
  }
}

// ============== CALCULATION RULES ==============
console.log('\n\n📐 CALCULATION RULES:\n');
const rules = db.prepare(`
  SELECT code, name, rule_type, parameters FROM calculation_rules ORDER BY code
`).all();

for (const rule of rules) {
  const icon = rule.rule_type === 'accrual' ? '💰' : rule.rule_type === 'tax' ? '📉' : '📊';
  const params = rule.parameters ? JSON.parse(rule.parameters) : {};
  const rate = params.rate ? ` (${(params.rate * 100).toFixed(1)}%)` : '';
  console.log(`  ${icon} ${rule.code}: ${rule.name}${rate}`);
}

// ============== CALCULATION TEMPLATES ==============
console.log('\n\n📋 CALCULATION TEMPLATES:\n');
const templates = db.prepare(`
  SELECT t.code, t.name, t.description FROM calculation_templates t
`).all();

for (const tmpl of templates) {
  console.log(`  📝 ${tmpl.code}: ${tmpl.name}`);
  console.log(`     ${tmpl.description}`);

  const templateRules = db.prepare(`
    SELECT r.code, r.name, tr.execution_order
    FROM template_rules tr
    JOIN calculation_rules r ON r.id = tr.rule_id
    WHERE tr.template_id = (SELECT id FROM calculation_templates WHERE code = ?)
    ORDER BY tr.execution_order
  `).all(tmpl.code);

  console.log('     Execution order:');
  for (const r of templateRules) {
    console.log(`       ${r.execution_order}. ${r.code} - ${r.name}`);
  }
}

// ============== BASE VALUES ==============
console.log('\n\n💵 BASE VALUES:\n');
const baseValues = db.prepare(`
  SELECT code, name, value, effective_from FROM base_values ORDER BY code
`).all();

for (const bv of baseValues) {
  console.log(`  ${bv.code}: ${bv.name} = ${bv.value.toLocaleString('uk-UA')} ₴ (from ${bv.effective_from})`);
}

// ============== SUMMARY ==============
console.log('\n\n' + '═'.repeat(70));
console.log('\n📈 SUMMARY:\n');

const stats = {
  employees: db.prepare('SELECT COUNT(*) as cnt FROM employees').get().cnt,
  orgUnits: db.prepare('SELECT COUNT(*) as cnt FROM org_units').get().cnt,
  contracts: db.prepare('SELECT COUNT(*) as cnt FROM contracts').get().cnt,
  rules: db.prepare('SELECT COUNT(*) as cnt FROM calculation_rules').get().cnt,
  templates: db.prepare('SELECT COUNT(*) as cnt FROM calculation_templates').get().cnt,
  accrualTypes: db.prepare('SELECT COUNT(*) as cnt FROM accrual_types').get().cnt,
  baseValues: db.prepare('SELECT COUNT(*) as cnt FROM base_values').get().cnt,
};

console.log(`  👥 Employees:           ${stats.employees}`);
console.log(`  🏢 Organizational units: ${stats.orgUnits}`);
console.log(`  📄 Contracts:           ${stats.contracts}`);
console.log(`  📐 Calculation rules:   ${stats.rules}`);
console.log(`  📋 Templates:           ${stats.templates}`);
console.log(`  🏷️  Accrual types:       ${stats.accrualTypes}`);
console.log(`  💵 Base values:         ${stats.baseValues}`);

db.close();
console.log('\n✅ Data overview complete!\n');
