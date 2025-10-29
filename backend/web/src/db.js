const fs = require('fs');
const path = require('path');
const sqlite3 = require('sqlite3').verbose();


const dbPath = path.join(__dirname, '..', 'data', 'ghostai.db');
const dbDir = path.dirname(dbPath);
if (!fs.existsSync(dbDir)) {
  fs.mkdirSync(dbDir, { recursive: true });
}
const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.error('Failed to connect to SQLite database', err);
  }
});

db.serialize(() => {
  db.run(
    `CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      token TEXT NOT NULL,
      plan TEXT NOT NULL DEFAULT 'free',
      referral TEXT DEFAULT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`
  );

  db.run(
    `CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email)`
  );
});

module.exports = db;
