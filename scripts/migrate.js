#!/usr/bin/env node
const Database = require('better-sqlite3');
const fs = require('fs');
const path = require('path');

const DB_PATH = path.join(__dirname, '..', 'data', 'payroll.db');
const MIGRATIONS_PATH = path.join(__dirname, '..', 'migrations');

console.log('🚀 Starting database migration...\n');
console.log(`Database: ${DB_PATH}`);
console.log(`Migrations: ${MIGRATIONS_PATH}\n`);

// Create database connection
const db = new Database(DB_PATH);

// Enable foreign keys
db.pragma('foreign_keys = ON');

// Get all migration files sorted
const migrationFiles = fs.readdirSync(MIGRATIONS_PATH)
  .filter(f => f.endsWith('.sql'))
  .sort();

console.log(`Found ${migrationFiles.length} migration files:\n`);

let successCount = 0;
let errorCount = 0;

for (const file of migrationFiles) {
  const filePath = path.join(MIGRATIONS_PATH, file);
  const sql = fs.readFileSync(filePath, 'utf-8');

  try {
    console.log(`📄 Running ${file}...`);
    db.exec(sql);
    console.log(`   ✅ Success\n`);
    successCount++;
  } catch (err) {
    console.log(`   ❌ Error: ${err.message}\n`);
    errorCount++;
  }
}

db.close();

console.log('═'.repeat(50));
console.log(`\n📊 Migration Summary:`);
console.log(`   ✅ Successful: ${successCount}`);
console.log(`   ❌ Failed: ${errorCount}`);
console.log(`\n✨ Database created at: ${DB_PATH}`);
