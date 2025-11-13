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
      token_balance INTEGER NOT NULL DEFAULT 0,
      referral TEXT DEFAULT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`
  );

  db.run(
    `CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email)`
  );

  db.all('PRAGMA table_info(users)', (err, columns) => {
    if (err) {
      console.error('Failed to inspect users table for migrations', err);
      return;
    }

    const hasTokenBalance = Array.isArray(columns)
      ? columns.some((column) => column && column.name === 'token_balance')
      : false;

    if (!hasTokenBalance) {
      db.run(
        `ALTER TABLE users ADD COLUMN token_balance INTEGER NOT NULL DEFAULT 0`,
        (alterErr) => {
          if (alterErr) {
            console.error('Failed to add token_balance column to users table', alterErr);
          }
        }
      );
    }
  });
});

module.exports = db;
