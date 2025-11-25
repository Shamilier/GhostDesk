const fs = require('fs');
const path = require('path');
const Knex = require('knex');
const { ConnectSessionKnexStore } = require('connect-session-knex');

const DEFAULT_SQLITE_FILENAME = 'sessions.db';

function resolveKnexConfig() {
  const connectionUrl = process.env.SESSION_DATABASE_URL;
  const clientFromEnv = process.env.SESSION_DB_CLIENT;

  if (connectionUrl) {
    const client = clientFromEnv || inferClientFromUrl(connectionUrl);
    return {
      client,
      connection: connectionUrl,
      pool: {
        min: Number(process.env.SESSION_DB_POOL_MIN || 2),
        max: Number(process.env.SESSION_DB_POOL_MAX || 10),
      },
      acquireConnectionTimeout: Number(process.env.SESSION_DB_ACQUIRE_TIMEOUT || 10_000),
    };
  }

  const dataDir = path.join(__dirname, '..', 'data');
  if (!fs.existsSync(dataDir)) {
    fs.mkdirSync(dataDir, { recursive: true });
  }

  const filename = process.env.SESSION_SQLITE_FILENAME || DEFAULT_SQLITE_FILENAME;
  const filepath = path.join(dataDir, filename);

  return {
    client: 'sqlite3',
    connection: { filename: filepath },
    useNullAsDefault: true,
    pool: {
      afterCreate: (conn, done) => {
        conn.run('PRAGMA journal_mode = WAL;', [], (err) => done(err, conn));
      },
    },
  };
}

function inferClientFromUrl(url) {
  try {
    const parsed = new URL(url);
    switch (parsed.protocol) {
      case 'postgres:':
      case 'postgresql:':
        return 'pg';
      case 'mysql:':
      case 'mysql2:':
        return 'mysql2';
      case 'mariadb:':
        return 'mariadb';
      case 'cockroachdb:':
        return 'cockroachdb';
      case 'sqlite:':
      case 'file:':
        return 'sqlite3';
      default:
        return process.env.SESSION_DB_CLIENT || 'pg';
    }
  } catch (err) {
    return process.env.SESSION_DB_CLIENT || 'pg';
  }
}

const knexConfig = resolveKnexConfig();
const knex = Knex(knexConfig);

const sessionTableName = process.env.SESSION_TABLE_NAME || 'sessions';

const store = new ConnectSessionKnexStore({
  knex,
  tableName: sessionTableName,
  createTable: process.env.SESSION_CREATE_TABLE ? process.env.SESSION_CREATE_TABLE === 'true' : true,
  cleanupInterval: Number(process.env.SESSION_CLEAR_INTERVAL || 60 * 60 * 1000),
});

async function shutdownSessionStore() {
  await knex.destroy();
}

module.exports = {
  store,
  knex,
  shutdownSessionStore,
};
