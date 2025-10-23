const crypto = require('crypto');
const db = require('./db');

const clients = {
  'ghostdesk-desktop': {
    id: 'ghostdesk-desktop',
    name: 'GhostDesk Desktop',
    redirectUris: ['ghostdesk://auth/callback'],
    public: true,
    scope: 'profile',
    prompt: 'login',
  },
};

const AUTH_CODE_TTL_SECONDS = 600; // 10 minutes
const ACCESS_TOKEN_TTL_SECONDS = 3600; // 1 hour
const REFRESH_TOKEN_TTL_SECONDS = 60 * 60 * 24 * 30; // 30 days

function migrate() {
  db.serialize(() => {
    db.run(
      `CREATE TABLE IF NOT EXISTS oauth_codes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        client_id TEXT NOT NULL,
        redirect_uri TEXT NOT NULL,
        code_hash TEXT NOT NULL UNIQUE,
        code_challenge TEXT NOT NULL,
        code_challenge_method TEXT NOT NULL,
        state TEXT,
        expires_at DATETIME NOT NULL,
        consumed_at DATETIME,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )`
    );

    db.run(
      `CREATE INDEX IF NOT EXISTS idx_oauth_codes_code_hash ON oauth_codes(code_hash)`
    );

    db.run(
      `CREATE TABLE IF NOT EXISTS oauth_tokens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        client_id TEXT NOT NULL,
        access_token_hash TEXT NOT NULL UNIQUE,
        refresh_token_hash TEXT UNIQUE,
        access_token_expires_at DATETIME NOT NULL,
        refresh_token_expires_at DATETIME,
        revoked INTEGER NOT NULL DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )`
    );

    db.run(
      `CREATE INDEX IF NOT EXISTS idx_oauth_tokens_access_hash ON oauth_tokens(access_token_hash)`
    );

    db.run(
      `CREATE INDEX IF NOT EXISTS idx_oauth_tokens_refresh_hash ON oauth_tokens(refresh_token_hash)`
    );
  });
}

function getClient(clientId) {
  return clients[clientId] || null;
}

function getPublicClientConfig(clientId) {
  const client = getClient(clientId);
  if (!client || !client.public) {
    return null;
  }

  return {
    clientId: client.id,
    redirectUri: client.redirectUris[0] || null,
    scope: client.scope || 'profile',
    prompt: client.prompt || null,
  };
}

function validateRedirectUri(client, redirectUri) {
  if (!client) {
    return false;
  }
  return client.redirectUris.includes(redirectUri);
}

function base64UrlEncode(buffer) {
  return buffer
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

function hashValue(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function createAuthorizationCode({
  userId,
  clientId,
  redirectUri,
  codeChallenge,
  codeChallengeMethod = 'S256',
  state = null,
}) {
  const code = base64UrlEncode(crypto.randomBytes(32));
  const codeHash = hashValue(code);
  const expiresAt = new Date(Date.now() + AUTH_CODE_TTL_SECONDS * 1000).toISOString();

  return new Promise((resolve, reject) => {
    const sql = `INSERT INTO oauth_codes (user_id, client_id, redirect_uri, code_hash, code_challenge, code_challenge_method, state, expires_at)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?)`;
    const params = [userId, clientId, redirectUri, codeHash, codeChallenge, codeChallengeMethod, state, expiresAt];

    db.run(sql, params, (err) => {
      if (err) {
        return reject(err);
      }
      return resolve({ code, expiresAt });
    });
  });
}

function consumeAuthorizationCode(code, clientId, redirectUri) {
  const codeHash = hashValue(code);
  const nowIso = new Date().toISOString();

  return new Promise((resolve, reject) => {
    db.get(
      `SELECT * FROM oauth_codes
       WHERE code_hash = ? AND client_id = ? AND redirect_uri = ? AND consumed_at IS NULL AND expires_at > ?`,
      [codeHash, clientId, redirectUri, nowIso],
      (err, row) => {
        if (err) {
          return reject(err);
        }
        if (!row) {
          return resolve(null);
        }
        db.run(
          `UPDATE oauth_codes SET consumed_at = ? WHERE id = ?`,
          [nowIso, row.id],
          (updateErr) => {
            if (updateErr) {
              return reject(updateErr);
            }
            return resolve(row);
          }
        );
      }
    );
  });
}

function createTokenPair({ userId, clientId }) {
  const accessToken = base64UrlEncode(crypto.randomBytes(32));
  const refreshToken = base64UrlEncode(crypto.randomBytes(48));
  const accessTokenHash = hashValue(accessToken);
  const refreshTokenHash = hashValue(refreshToken);
  const accessTokenExpiresAt = new Date(Date.now() + ACCESS_TOKEN_TTL_SECONDS * 1000).toISOString();
  const refreshTokenExpiresAt = new Date(Date.now() + REFRESH_TOKEN_TTL_SECONDS * 1000).toISOString();

  return new Promise((resolve, reject) => {
    const sql = `INSERT INTO oauth_tokens (user_id, client_id, access_token_hash, refresh_token_hash, access_token_expires_at, refresh_token_expires_at)
                 VALUES (?, ?, ?, ?, ?, ?)`;
    const params = [userId, clientId, accessTokenHash, refreshTokenHash, accessTokenExpiresAt, refreshTokenExpiresAt];

    db.run(sql, params, (err) => {
      if (err) {
        return reject(err);
      }
      resolve({
        accessToken,
        refreshToken,
        accessTokenExpiresAt,
        refreshTokenExpiresAt,
      });
    });
  });
}

function findTokenByRefreshToken(refreshToken, clientId) {
  const refreshTokenHash = hashValue(refreshToken);
  const nowIso = new Date().toISOString();

  return new Promise((resolve, reject) => {
    db.get(
      `SELECT * FROM oauth_tokens WHERE refresh_token_hash = ? AND client_id = ? AND revoked = 0 AND refresh_token_expires_at > ?`,
      [refreshTokenHash, clientId, nowIso],
      (err, row) => {
        if (err) {
          return reject(err);
        }
        resolve(row || null);
      }
    );
  });
}

function getUserByAccessToken(accessToken) {
  const accessTokenHash = hashValue(accessToken);
  const nowIso = new Date().toISOString();

  return new Promise((resolve, reject) => {
    db.get(
      `SELECT oauth_tokens.*, users.email, users.plan, users.referral, users.created_at, users.token AS user_token
       FROM oauth_tokens
       JOIN users ON users.id = oauth_tokens.user_id
       WHERE oauth_tokens.access_token_hash = ? AND oauth_tokens.access_token_expires_at > ? AND oauth_tokens.revoked = 0`,
      [accessTokenHash, nowIso],
      (err, row) => {
        if (err) {
          return reject(err);
        }
        resolve(row || null);
      }
    );
  });
}

function revokeByRefreshToken(refreshToken, clientId) {
  const refreshTokenHash = hashValue(refreshToken);

  return new Promise((resolve, reject) => {
    db.run(
      `UPDATE oauth_tokens SET revoked = 1 WHERE refresh_token_hash = ? AND client_id = ?`,
      [refreshTokenHash, clientId],
      (err) => {
        if (err) {
          return reject(err);
        }
        resolve();
      }
    );
  });
}

migrate();

module.exports = {
  clients,
  getClient,
  getPublicClientConfig,
  validateRedirectUri,
  createAuthorizationCode,
  consumeAuthorizationCode,
  createTokenPair,
  findTokenByRefreshToken,
  getUserByAccessToken,
  revokeByRefreshToken,
  ACCESS_TOKEN_TTL_SECONDS,
  REFRESH_TOKEN_TTL_SECONDS,
};
