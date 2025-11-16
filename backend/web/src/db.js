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

const ensureSubscriptionColumns = (initialColumns) => {
  const applyEnsures = (columns) => {
    const columnNames = new Set(
      Array.isArray(columns)
        ? columns
            .map((column) => (column && typeof column.name === 'string' ? column.name : null))
            .filter(Boolean)
        : []
    );

    const ensureColumn = (columnName) => {
      if (columnNames.has(columnName)) {
        return;
      }

      db.run(
        `ALTER TABLE users ADD COLUMN ${columnName} TEXT DEFAULT NULL`,
        (alterErr) => {
          if (alterErr) {
            console.error(`Failed to add ${columnName} column to users table`, alterErr);
          }
        }
      );
    };

    ensureColumn('plan_renews_at');
    ensureColumn('free_tokens_refresh_at');
  };

  if (initialColumns) {
    applyEnsures(initialColumns);
    return;
  }

  db.all('PRAGMA table_info(users)', (err, columns) => {
    if (err) {
      console.error('Failed to inspect users table for subscription columns', err);
      return;
    }

    applyEnsures(columns);
  });
};

db.serialize(() => {
  db.run(
    `CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      token TEXT NOT NULL,
      plan TEXT NOT NULL DEFAULT 'free',
      token_balance REAL NOT NULL DEFAULT 0,
      plan_renews_at TEXT DEFAULT NULL,
      free_tokens_refresh_at TEXT DEFAULT NULL,
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

    const tokenBalanceColumn = Array.isArray(columns)
      ? columns.find((column) => column && column.name === 'token_balance')
      : null;

    if (!tokenBalanceColumn) {
      db.run(
        `ALTER TABLE users ADD COLUMN token_balance REAL NOT NULL DEFAULT 0`,
        (alterErr) => {
          if (alterErr) {
            console.error('Failed to add token_balance column to users table', alterErr);
            return;
          }
          ensureSubscriptionColumns();
        }
      );
      return;
    }

    const columnType = typeof tokenBalanceColumn.type === 'string'
      ? tokenBalanceColumn.type.trim().toUpperCase()
      : '';

    if (columnType === 'REAL') {
      ensureSubscriptionColumns(columns);
      return;
    }

    const migrationStatements = [
      { sql: 'BEGIN TRANSACTION' },
      { sql: 'ALTER TABLE users RENAME TO users_old' },
      {
        sql: `CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          email TEXT NOT NULL UNIQUE,
          password_hash TEXT NOT NULL,
          token TEXT NOT NULL,
          plan TEXT NOT NULL DEFAULT 'free',
          token_balance REAL NOT NULL DEFAULT 0,
          plan_renews_at TEXT DEFAULT NULL,
          free_tokens_refresh_at TEXT DEFAULT NULL,
          referral TEXT DEFAULT NULL,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )`,
      },
      {
        sql: `INSERT INTO users (id, email, password_hash, token, plan, token_balance, plan_renews_at, free_tokens_refresh_at, referral, created_at)
              SELECT id, email, password_hash, token, plan, CAST(token_balance AS REAL), NULL AS plan_renews_at, NULL AS free_tokens_refresh_at, referral, created_at
              FROM users_old`,
      },
      { sql: 'DROP TABLE IF EXISTS users_old' },
      { sql: 'CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email)' },
      { sql: 'COMMIT' },
    ];

    const runMigrationStep = (index) => {
      if (index >= migrationStatements.length) {
        console.info('Migrated users.token_balance column to REAL type');
        ensureSubscriptionColumns();
        return;
      }

      const { sql, params } = migrationStatements[index];
      db.run(sql, params || [], (stepErr) => {
        if (stepErr) {
          console.error('Failed during token_balance REAL migration step', {
            error: stepErr,
            sql,
          });
          if (index > 0) {
            db.run('ROLLBACK', (rollbackErr) => {
              if (rollbackErr) {
                console.error('Failed to rollback token_balance REAL migration', rollbackErr);
              }
            });
          }
          return;
        }

        runMigrationStep(index + 1);
      });
    };

    runMigrationStep(0);
  });
});

module.exports = db;
