#!/usr/bin/env node
const Database = require('better-sqlite3');
const path = require('path');

const DB_PATH = path.join(__dirname, '..', 'data', 'payroll.db');

console.log('📋 Database Schema Check\n');
console.log('═'.repeat(60));

const db = new Database(DB_PATH, { readonly: true });

// Get all tables
const tables = db.prepare(`
  SELECT name FROM sqlite_master
  WHERE type='table' AND name NOT LIKE 'sqlite_%'
  ORDER BY name
`).all();

console.log(`\n📊 Total tables: ${tables.length}\n`);

// Group tables by module
const modules = {
  'Module 1 - Structure & Employees': ['org_units', 'employees', 'employee_org_unit_history', 'contracts', 'calculation_rules', 'calculation_templates', 'template_rules', 'rule_versions'],
  'Module 2 - Work Results': ['work_results', 'timesheets', 'production_results'],
  'Module 3 - Periods & Accruals': ['calculation_periods', 'accrual_documents', 'accrual_results', 'accrual_operations', 'accrual_parts', 'change_requests'],
  'Module 4 - Payments': ['payment_rules', 'payment_documents', 'payment_items', 'payment_operations', 'payment_accrual_links', 'bank_statements'],
  'Auxiliary Tables': ['accrual_types', 'base_values', 'employee_bases', 'employee_categories_history', 'schema_meta']
};

const tableNames = tables.map(t => t.name);

for (const [moduleName, expectedTables] of Object.entries(modules)) {
  console.log(`\n📁 ${moduleName}:`);
  for (const table of expectedTables) {
    const exists = tableNames.includes(table);
    const icon = exists ? '✅' : '❌';

    if (exists) {
      const count = db.prepare(`SELECT COUNT(*) as cnt FROM ${table}`).get().cnt;
      console.log(`   ${icon} ${table} (${count} rows)`);
    } else {
      console.log(`   ${icon} ${table} (MISSING)`);
    }
  }
}

// Check for any extra tables
const allExpected = Object.values(modules).flat();
const extras = tableNames.filter(t => !allExpected.includes(t));
if (extras.length > 0) {
  console.log('\n📌 Additional tables:');
  for (const table of extras) {
    const count = db.prepare(`SELECT COUNT(*) as cnt FROM ${table}`).get().cnt;
    console.log(`   ℹ️  ${table} (${count} rows)`);
  }
}

// Schema version
const version = db.prepare('SELECT version, description, applied_at FROM schema_meta ORDER BY id DESC LIMIT 1').get();
console.log('\n' + '═'.repeat(60));
console.log(`\n📌 Schema Version: ${version.version}`);
console.log(`   Description: ${version.description}`);
console.log(`   Applied: ${version.applied_at}`);

db.close();
console.log('\n✅ Schema check complete!\n');
