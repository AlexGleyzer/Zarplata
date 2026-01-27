/**
 * Система міграцій для SQLite
 *
 * Команди:
 *   npm run db:migrate          - Застосувати всі нові міграції
 *   npm run db:migrate:status   - Показати статус міграцій
 *   npm run db:migrate:rollback - Відкотити останню міграцію
 *   npm run db:migrate:create   - Створити нову міграцію
 */

import Database from 'better-sqlite3';
import { readFileSync, readdirSync, writeFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { createHash } from 'crypto';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = join(__dirname, '../..');
const DB_PATH = join(ROOT_DIR, 'data/payroll.db');
const MIGRATIONS_DIR = join(ROOT_DIR, 'migrations');

// Кольори для консолі
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  gray: '\x1b[90m',
};

function log(color, ...args) {
  console.log(color, ...args, colors.reset);
}

/**
 * Підключення до БД
 */
function getDatabase() {
  const db = new Database(DB_PATH);
  db.pragma('foreign_keys = ON');
  return db;
}

/**
 * Ініціалізація таблиці міграцій
 */
function ensureMigrationsTable(db) {
  const migrationsSql = readFileSync(
    join(ROOT_DIR, 'sql/000_migrations_table.sql'),
    'utf-8'
  );
  db.exec(migrationsSql);
}

/**
 * Отримати список застосованих міграцій
 */
function getAppliedMigrations(db) {
  const rows = db.prepare(`
    SELECT version, name, applied_at, status
    FROM _migrations
    WHERE status = 'applied'
    ORDER BY version
  `).all();

  return new Map(rows.map(r => [r.version, r]));
}

/**
 * Отримати список файлів міграцій
 */
function getMigrationFiles() {
  if (!existsSync(MIGRATIONS_DIR)) {
    return [];
  }

  return readdirSync(MIGRATIONS_DIR)
    .filter(f => f.endsWith('.sql'))
    .sort()
    .map(filename => {
      // Формат: V001__description.sql
      const match = filename.match(/^V(\d+)__(.+)\.sql$/);
      if (!match) {
        log(colors.yellow, `⚠️  Пропускаємо файл з невірним форматом: ${filename}`);
        return null;
      }

      return {
        filename,
        version: match[1],
        name: match[2].replace(/_/g, ' '),
        path: join(MIGRATIONS_DIR, filename),
      };
    })
    .filter(Boolean);
}

/**
 * Обчислити checksum файлу
 */
function getChecksum(content) {
  return createHash('md5').update(content).digest('hex');
}

/**
 * Застосувати міграцію
 */
function applyMigration(db, migration) {
  const content = readFileSync(migration.path, 'utf-8');
  const checksum = getChecksum(content);

  const startTime = Date.now();

  try {
    // Виконуємо міграцію в транзакції
    db.exec('BEGIN TRANSACTION');
    db.exec(content);

    // Записуємо інформацію про міграцію
    db.prepare(`
      INSERT INTO _migrations (version, name, checksum, execution_time_ms, status)
      VALUES (?, ?, ?, ?, 'applied')
    `).run(
      migration.version,
      migration.name,
      checksum,
      Date.now() - startTime
    );

    db.exec('COMMIT');
    return true;

  } catch (error) {
    db.exec('ROLLBACK');

    // Записуємо невдалу міграцію
    db.prepare(`
      INSERT OR REPLACE INTO _migrations (version, name, checksum, execution_time_ms, status)
      VALUES (?, ?, ?, ?, 'failed')
    `).run(
      migration.version,
      migration.name,
      checksum,
      Date.now() - startTime
    );

    throw error;
  }
}

/**
 * Команда: migrate (застосувати нові міграції)
 */
async function migrate() {
  log(colors.blue, '\n🔄 Запуск міграцій...\n');

  const db = getDatabase();

  try {
    ensureMigrationsTable(db);

    const applied = getAppliedMigrations(db);
    const migrations = getMigrationFiles();

    const pending = migrations.filter(m => !applied.has(m.version));

    if (pending.length === 0) {
      log(colors.green, '✅ Всі міграції вже застосовані');
      return;
    }

    log(colors.gray, `📋 Знайдено ${pending.length} нових міграцій:\n`);

    for (const migration of pending) {
      process.stdout.write(`   ${migration.version}: ${migration.name}... `);

      try {
        applyMigration(db, migration);
        log(colors.green, '✅');
      } catch (error) {
        log(colors.red, '❌');
        log(colors.red, `\n   Помилка: ${error.message}`);
        process.exit(1);
      }
    }

    log(colors.green, `\n🎉 Успішно застосовано ${pending.length} міграцій`);

  } finally {
    db.close();
  }
}

/**
 * Команда: status (показати статус міграцій)
 */
async function status() {
  log(colors.blue, '\n📊 Статус міграцій\n');

  const db = getDatabase();

  try {
    ensureMigrationsTable(db);

    const applied = getAppliedMigrations(db);
    const migrations = getMigrationFiles();

    if (migrations.length === 0 && applied.size === 0) {
      log(colors.yellow, '   Міграцій немає');
      return;
    }

    // Показуємо застосовані міграції
    log(colors.gray, '   Версія  │ Статус      │ Назва');
    log(colors.gray, '   ────────┼─────────────┼────────────────────────');

    // Спочатку з бази (включно з initial)
    const allFromDb = db.prepare(`
      SELECT version, name, applied_at, status
      FROM _migrations
      ORDER BY version
    `).all();

    for (const row of allFromDb) {
      const statusIcon = row.status === 'applied' ? '✅ Applied' :
                        row.status === 'failed' ? '❌ Failed' : '⏪ Rolled back';
      const statusColor = row.status === 'applied' ? colors.green :
                         row.status === 'failed' ? colors.red : colors.yellow;

      log(statusColor, `   ${row.version.padEnd(6)} │ ${statusIcon.padEnd(11)} │ ${row.name}`);
    }

    // Показуємо незастосовані
    const pending = migrations.filter(m => !applied.has(m.version));
    for (const m of pending) {
      log(colors.yellow, `   ${m.version.padEnd(6)} │ ⏳ Pending   │ ${m.name}`);
    }

    log(colors.gray, '\n   ────────────────────────────────────────────────');
    log(colors.gray, `   Всього: ${allFromDb.length} застосовано, ${pending.length} очікує`);

  } finally {
    db.close();
  }
}

/**
 * Команда: create (створити нову міграцію)
 */
async function create(name) {
  if (!name) {
    log(colors.red, '❌ Вкажіть назву міграції');
    log(colors.gray, '   Приклад: npm run db:migrate:create add_employee_bonus_field');
    process.exit(1);
  }

  const migrations = getMigrationFiles();
  const lastVersion = migrations.length > 0
    ? parseInt(migrations[migrations.length - 1].version, 10)
    : 0;

  const newVersion = String(lastVersion + 1).padStart(3, '0');
  const filename = `V${newVersion}__${name.replace(/\s+/g, '_')}.sql`;
  const filepath = join(MIGRATIONS_DIR, filename);

  const template = `-- ============================================================================
-- Міграція V${newVersion}: ${name.replace(/_/g, ' ')}
-- Дата: ${new Date().toISOString().split('T')[0]}
-- ============================================================================

-- UP: Застосування міграції
-- ----------------------------------------------------------------------------



-- ============================================================================
-- ROLLBACK (для ручного відкату, якщо потрібно)
-- ============================================================================
-- DROP TABLE IF EXISTS ...;
-- ALTER TABLE ... DROP COLUMN ...;
`;

  writeFileSync(filepath, template);

  log(colors.green, `\n✅ Створено міграцію: ${filename}`);
  log(colors.gray, `   Шлях: ${filepath}`);
  log(colors.gray, `\n   Відредагуйте файл та запустіть: npm run db:migrate`);
}

/**
 * Команда: rollback (відкотити останню міграцію)
 */
async function rollback() {
  log(colors.yellow, '\n⚠️  Автоматичний rollback не підтримується для SQLite');
  log(colors.gray, '   SQLite не підтримує DROP COLUMN та інші операції.');
  log(colors.gray, '   Для відкату:');
  log(colors.gray, '   1. Створіть нову міграцію з протилежними змінами');
  log(colors.gray, '   2. Або відновіть БД з бекапу');
  log(colors.gray, '\n   Рекомендація: завжди робіть бекап перед міграцією:');
  log(colors.gray, '   cp data/payroll.db data/backups/payroll_$(date +%Y%m%d_%H%M%S).db');
}

// Головна функція
const command = process.argv[2] || 'up';
const arg = process.argv[3];

switch (command) {
  case 'up':
  case 'migrate':
    migrate();
    break;
  case 'status':
    status();
    break;
  case 'create':
    create(arg);
    break;
  case 'rollback':
    rollback();
    break;
  default:
    log(colors.red, `❌ Невідома команда: ${command}`);
    log(colors.gray, '\nДоступні команди:');
    log(colors.gray, '  up, migrate  - Застосувати нові міграції');
    log(colors.gray, '  status       - Показати статус міграцій');
    log(colors.gray, '  create NAME  - Створити нову міграцію');
    log(colors.gray, '  rollback     - Інформація про відкат');
    process.exit(1);
}
