// scripts/migrate.js
// Простий migration runner для SQLite
// Запускає всі *.sql з db/migrations, які ще не були застосовані

const fs = require("fs");
const path = require("path");
const sqlite3 = require("sqlite3").verbose();

// шляхи
const ROOT_DIR = path.join(__dirname, "..");
const DB_PATH = path.join(ROOT_DIR, "data", "payroll.db");
const MIGRATIONS_DIR = path.join(ROOT_DIR, "db", "migrations");

// перевірки
if (!fs.existsSync(DB_PATH)) {
  console.error("❌ Не знайдено базу:", DB_PATH);
  process.exit(1);
}

if (!fs.existsSync(MIGRATIONS_DIR)) {
  console.error("❌ Не знайдено папку міграцій:", MIGRATIONS_DIR);
  process.exit(1);
}

const db = new sqlite3.Database(DB_PATH);

db.serialize(() => {
  // 1. таблиця обліку міграцій
  db.run(
    `
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      filename TEXT UNIQUE NOT NULL,
      applied_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `,
    (err) => {
      if (err) {
        console.error("❌ Помилка створення schema_migrations:", err.message);
        process.exit(1);
      }

      runMigrations();
    }
  );
});

function runMigrations() {
  const files = fs
    .readdirSync(MIGRATIONS_DIR)
    .filter((f) => f.endsWith(".sql"))
    .sort();

  if (files.length === 0) {
    console.log("ℹ️ У папці migrations немає .sql файлів");
    db.close();
    return;
  }

  db.all(`SELECT filename FROM schema_migrations`, (err, rows) => {
    if (err) {
      console.error("❌ Помилка читання schema_migrations:", err.message);
      process.exit(1);
    }

    const applied = new Set(rows.map((r) => r.filename));
    const pending = files.filter((f) => !applied.has(f));

    if (pending.length === 0) {
      console.log("✅ Немає нових міграцій. Все актуально");
      db.close();
      return;
    }

    console.log("🧱 Нові міграції:");
    pending.forEach((f) => console.log("  -", f));

    applyNext(pending, 0);
  });
}

function applyNext(files, index) {
  if (index >= files.length) {
    console.log("🎉 Усі міграції застосовано");
    db.close();
    return;
  }

  const filename = files[index];
  const fullPath = path.join(MIGRATIONS_DIR, filename);
  const sql = fs.readFileSync(fullPath, "utf8");

  console.log(`\n▶ Застосування: ${filename}`);

  db.exec(sql, (err) => {
    if (err) {
      console.error(`❌ Помилка в ${filename}:`, err.message);
      process.exit(1);
    }

    db.run(
      `INSERT INTO schema_migrations (filename) VALUES (?)`,
      filename,
      (err2) => {
        if (err2) {
          console.error(
            `❌ Не вдалося зафіксувати ${filename}:`,
            err2.message
          );
          process.exit(1);
        }

        console.log(`✅ Готово: ${filename}`);
        applyNext(files, index + 1);
      }
    );
  });
}
