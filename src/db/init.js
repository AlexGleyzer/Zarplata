/**
 * Ініціалізація бази даних SQLite
 * Запуск: npm run db:init
 */

import Database from 'better-sqlite3';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = join(__dirname, '../..');
const DB_PATH = join(ROOT_DIR, 'data/payroll.db');

async function initDatabase() {
  console.log('🗄️  Ініціалізація бази даних...');
  console.log(`📁 Шлях: ${DB_PATH}`);

  // Створюємо з'єднання
  const db = new Database(DB_PATH);

  // Увімкнення foreign keys
  db.pragma('foreign_keys = ON');

  try {
    // Читаємо та виконуємо схему
    console.log('\n📋 Створення структури БД...');
    const schema = readFileSync(join(ROOT_DIR, 'sql/001_schema.sql'), 'utf-8');
    db.exec(schema);
    console.log('✅ Структура створена');

    // Запитуємо чи додавати тестові дані
    console.log('\n📊 Завантаження тестових даних...');
    const seedData = readFileSync(join(ROOT_DIR, 'sql/002_seed_data.sql'), 'utf-8');
    db.exec(seedData);
    console.log('✅ Тестові дані завантажено');

    // Перевіряємо створені таблиці
    const tables = db.prepare(`
      SELECT name FROM sqlite_master
      WHERE type='table'
      ORDER BY name
    `).all();

    console.log(`\n📊 Створено таблиць: ${tables.length}`);
    console.log('   Основні таблиці:');
    tables.slice(0, 10).forEach(t => console.log(`   - ${t.name}`));
    if (tables.length > 10) {
      console.log(`   ... та ще ${tables.length - 10} таблиць`);
    }

    // Статистика
    const employees = db.prepare('SELECT COUNT(*) as count FROM employees').get();
    const departments = db.prepare('SELECT COUNT(*) as count FROM departments').get();
    const positions = db.prepare('SELECT COUNT(*) as count FROM positions').get();

    console.log('\n📈 Статистика:');
    console.log(`   Працівників: ${employees.count}`);
    console.log(`   Підрозділів: ${departments.count}`);
    console.log(`   Посад: ${positions.count}`);

    console.log('\n🎉 База даних успішно ініціалізована!');

  } catch (error) {
    console.error('❌ Помилка:', error.message);
    process.exit(1);
  } finally {
    db.close();
  }
}

initDatabase();
