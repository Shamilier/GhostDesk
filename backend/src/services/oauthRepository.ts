import type { Database as DatabaseInstance } from "better-sqlite3";
import { createHash, randomBytes } from "node:crypto";

export type PkceMethod = "S256";

export type OAuthErrorCode =
  | "invalid_request"
  | "invalid_grant"
  | "invalid_client"
  | "unauthorized_client"
  | "pkce_mismatch";

export class OAuthFlowError extends Error {
  constructor(
    public readonly error: OAuthErrorCode,
    message: string,
    public readonly status = 400
  ) {
    super(message);
  }
}

export interface AuthorizationCodeInput {
  userToken: string;
  clientId: string;
  redirectUri: string;
  codeChallenge: string;
  scope: string;
  lifetimeSeconds: number;
}

export interface TokenIssueResult {
  accessToken: string;
  accessTokenExpiresAt: number;
  refreshToken: string;
  refreshTokenExpiresAt: number;
  scope: string;
}

export interface RedeemCodeParams {
  code: string;
  codeVerifier: string;
  clientId: string;
  redirectUri: string;
  accessTokenTTLSeconds: number;
  refreshTokenTTLSeconds: number;
  plan?: string;
  referral?: string;
}

export interface RotateRefreshTokenParams {
  refreshToken: string;
  clientId: string;
  accessTokenTTLSeconds: number;
  refreshTokenTTLSeconds: number;
}

interface AuthorizationCodeRow {
  code: string;
  user_token: string;
  client_id: string;
  redirect_uri: string;
  code_challenge: string;
  code_challenge_method: PkceMethod;
  scope: string | null;
  expires_at: number;
  consumed: number;
}

interface RefreshTokenRow {
  token: string;
  user_token: string;
  client_id: string;
  scope: string | null;
  plan: string | null;
  referral: string | null;
  created_at: number;
  expires_at: number;
  rotated_from: string | null;
  revoked: number;
}

export class OAuthRepository {
  constructor(private readonly db: DatabaseInstance) {}

  initialize(): void {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS oauth_clients (
        client_id TEXT PRIMARY KEY,
        name      TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS oauth_redirect_uris (
        client_id    TEXT NOT NULL REFERENCES oauth_clients(client_id) ON DELETE CASCADE,
        redirect_uri TEXT NOT NULL,
        PRIMARY KEY (client_id, redirect_uri)
      );

      CREATE TABLE IF NOT EXISTS oauth_authorization_codes (
        code        TEXT PRIMARY KEY,
        user_token  TEXT NOT NULL REFERENCES users(token) ON DELETE CASCADE,
        client_id   TEXT NOT NULL REFERENCES oauth_clients(client_id) ON DELETE CASCADE,
        redirect_uri TEXT NOT NULL,
        code_challenge TEXT NOT NULL,
        code_challenge_method TEXT NOT NULL CHECK (code_challenge_method IN ('S256')),
        scope       TEXT,
        expires_at  INTEGER NOT NULL,
        consumed    INTEGER NOT NULL DEFAULT 0
      );
      CREATE INDEX IF NOT EXISTS ix_oauth_codes_expires ON oauth_authorization_codes(expires_at);

      CREATE TABLE IF NOT EXISTS oauth_access_tokens (
        token      TEXT PRIMARY KEY,
        user_token TEXT NOT NULL REFERENCES users(token) ON DELETE CASCADE,
        client_id  TEXT NOT NULL REFERENCES oauth_clients(client_id) ON DELETE CASCADE,
        scope      TEXT,
        plan       TEXT,
        referral   TEXT,
        created_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS ix_oauth_access_user ON oauth_access_tokens(user_token);

      CREATE TABLE IF NOT EXISTS oauth_refresh_tokens (
        token        TEXT PRIMARY KEY,
        user_token   TEXT NOT NULL REFERENCES users(token) ON DELETE CASCADE,
        client_id    TEXT NOT NULL REFERENCES oauth_clients(client_id) ON DELETE CASCADE,
        scope        TEXT,
        plan         TEXT,
        referral     TEXT,
        created_at   INTEGER NOT NULL,
        expires_at   INTEGER NOT NULL,
        rotated_from TEXT,
        revoked      INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(rotated_from) REFERENCES oauth_refresh_tokens(token) ON DELETE SET NULL
      );
      CREATE INDEX IF NOT EXISTS ix_oauth_refresh_user ON oauth_refresh_tokens(user_token);

      INSERT OR IGNORE INTO oauth_clients(client_id, name)
      VALUES ('ghostdesk-desktop', 'GhostDesk macOS');

      INSERT OR IGNORE INTO oauth_redirect_uris(client_id, redirect_uri)
      VALUES ('ghostdesk-desktop', 'ghostdesk://auth/callback');
    `);
  }

  cleanupExpiredRecords(): void {
    const now = Date.now();
    const deleteCodes = this.db.prepare(
      `DELETE FROM oauth_authorization_codes WHERE expires_at < ? OR consumed = 1`
    );
    const deleteAccess = this.db.prepare(
      `DELETE FROM oauth_access_tokens WHERE expires_at < ?`
    );
    const deleteRefresh = this.db.prepare(
      `DELETE FROM oauth_refresh_tokens WHERE expires_at < ? OR revoked = 1`
    );
    const transaction = this.db.transaction((timestamp: number) => {
      deleteCodes.run(timestamp);
      deleteAccess.run(timestamp);
      deleteRefresh.run(timestamp);
    });
    transaction(now);
  }

  listRedirectUris(clientId: string): string[] {
    const stmt = this.db.prepare<unknown[], { redirect_uri: string }>(
      `SELECT redirect_uri FROM oauth_redirect_uris WHERE client_id = ?`
    );
    return stmt.all(clientId).map((row: { redirect_uri: string }) => row.redirect_uri);
  }

  assertClientExists(clientId: string): void {
    const stmt = this.db.prepare(`SELECT 1 FROM oauth_clients WHERE client_id = ? LIMIT 1`);
    const exists = stmt.get(clientId);
    if (!exists) {
      throw new OAuthFlowError("unauthorized_client", "Unknown OAuth client");
    }
  }

  createAuthorizationCode(input: AuthorizationCodeInput): { code: string; expiresAt: number } {
    this.cleanupExpiredRecords();
    this.assertClientExists(input.clientId);

    const allowed = this.listRedirectUris(input.clientId);
    if (!allowed.includes(input.redirectUri)) {
      throw new OAuthFlowError("invalid_request", "redirect_uri is not registered for client");
    }

    const code = generateToken(24);
    const expiresAt = Date.now() + input.lifetimeSeconds * 1000;
    const stmt = this.db.prepare(
      `INSERT INTO oauth_authorization_codes (
        code, user_token, client_id, redirect_uri, code_challenge, code_challenge_method, scope, expires_at
      ) VALUES (?, ?, ?, ?, ?, 'S256', ?, ?)`
    );

    try {
      stmt.run(
        code,
        input.userToken,
        input.clientId,
        input.redirectUri,
        input.codeChallenge,
        input.scope,
        expiresAt
      );
    } catch (error) {
      throw new OAuthFlowError("invalid_request", "Unable to create authorization code");
    }

    return { code, expiresAt };
  }

  redeemAuthorizationCode(params: RedeemCodeParams): TokenIssueResult {
    this.cleanupExpiredRecords();
    const redeem = this.db.transaction((input: RedeemCodeParams): TokenIssueResult => {
      const row = this.db
        .prepare<string[], AuthorizationCodeRow>(
          `SELECT code, user_token, client_id, redirect_uri, code_challenge, code_challenge_method, scope, expires_at, consumed
           FROM oauth_authorization_codes
           WHERE code = ?`
        )
        .get(input.code);

      if (!row) {
        throw new OAuthFlowError("invalid_grant", "Authorization code not found");
      }

      if (row.consumed) {
        throw new OAuthFlowError("invalid_grant", "Authorization code already used");
      }

      if (row.expires_at <= Date.now()) {
        throw new OAuthFlowError("invalid_grant", "Authorization code expired");
      }

      if (row.client_id !== input.clientId) {
        throw new OAuthFlowError("invalid_grant", "client_id mismatch");
      }

      if (row.redirect_uri !== input.redirectUri) {
        throw new OAuthFlowError("invalid_grant", "redirect_uri mismatch");
      }

      if (!verifyPkce(input.codeVerifier, row.code_challenge, row.code_challenge_method)) {
        throw new OAuthFlowError("pkce_mismatch", "PKCE verification failed");
      }

      const consumeResult = this.db
        .prepare(`UPDATE oauth_authorization_codes SET consumed = 1 WHERE code = ? AND consumed = 0`)
        .run(input.code);

      if (consumeResult.changes === 0) {
        throw new OAuthFlowError("invalid_grant", "Authorization code already consumed");
      }

      const now = Date.now();
      const accessToken = generateToken(32);
      const accessExpiresAt = now + input.accessTokenTTLSeconds * 1000;
      const refreshToken = generateToken(32);
      const refreshExpiresAt = now + input.refreshTokenTTLSeconds * 1000;

      const scope = row.scope ?? "";

      this.db
        .prepare(
          `INSERT INTO oauth_access_tokens (
            token, user_token, client_id, scope, plan, referral, created_at, expires_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
        )
        .run(
          accessToken,
          row.user_token,
          row.client_id,
          scope,
          params.plan ?? null,
          params.referral ?? null,
          now,
          accessExpiresAt
        );

      this.db
        .prepare(
          `INSERT INTO oauth_refresh_tokens (
            token, user_token, client_id, scope, plan, referral, created_at, expires_at, rotated_from, revoked
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, 0)`
        )
        .run(
          refreshToken,
          row.user_token,
          row.client_id,
          scope,
          params.plan ?? null,
          params.referral ?? null,
          now,
          refreshExpiresAt
        );

      return {
        accessToken,
        accessTokenExpiresAt: accessExpiresAt,
        refreshToken,
        refreshTokenExpiresAt: refreshExpiresAt,
        scope,
      };
    });

    try {
      return redeem(params);
    } catch (error) {
      if (error instanceof OAuthFlowError) {
        throw error;
      }
      throw new OAuthFlowError("invalid_grant", "Failed to redeem authorization code");
    }
  }

  rotateRefreshToken(params: RotateRefreshTokenParams): TokenIssueResult {
    this.cleanupExpiredRecords();
    const rotate = this.db.transaction((input: RotateRefreshTokenParams): TokenIssueResult => {
      const row = this.db
        .prepare<string[], RefreshTokenRow>(
          `SELECT token, user_token, client_id, scope, plan, referral, created_at, expires_at, rotated_from, revoked
           FROM oauth_refresh_tokens
           WHERE token = ?`
        )
        .get(input.refreshToken);

      if (!row) {
        throw new OAuthFlowError("invalid_grant", "Refresh token not found");
      }

      if (row.client_id !== input.clientId) {
        throw new OAuthFlowError("invalid_grant", "client_id mismatch");
      }

      if (row.revoked) {
        throw new OAuthFlowError("invalid_grant", "Refresh token already revoked");
      }

      if (row.expires_at <= Date.now()) {
        throw new OAuthFlowError("invalid_grant", "Refresh token expired");
      }

      this.db
        .prepare(`UPDATE oauth_refresh_tokens SET revoked = 1 WHERE token = ? AND revoked = 0`)
        .run(input.refreshToken);

      const now = Date.now();
      const accessToken = generateToken(32);
      const accessExpiresAt = now + input.accessTokenTTLSeconds * 1000;
      const refreshToken = generateToken(32);
      const refreshExpiresAt = now + input.refreshTokenTTLSeconds * 1000;
      const scope = row.scope ?? "";

      this.db
        .prepare(
          `INSERT INTO oauth_access_tokens (
            token, user_token, client_id, scope, plan, referral, created_at, expires_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
        )
        .run(
          accessToken,
          row.user_token,
          row.client_id,
          scope,
          row.plan,
          row.referral,
          now,
          accessExpiresAt
        );

      this.db
        .prepare(
          `INSERT INTO oauth_refresh_tokens (
            token, user_token, client_id, scope, plan, referral, created_at, expires_at, rotated_from, revoked
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0)`
        )
        .run(
          refreshToken,
          row.user_token,
          row.client_id,
          scope,
          row.plan,
          row.referral,
          now,
          refreshExpiresAt,
          row.token
        );

      return {
        accessToken,
        accessTokenExpiresAt: accessExpiresAt,
        refreshToken,
        refreshTokenExpiresAt: refreshExpiresAt,
        scope,
      };
    });

    try {
      return rotate(params);
    } catch (error) {
      if (error instanceof OAuthFlowError) {
        throw error;
      }
      throw new OAuthFlowError("invalid_grant", "Failed to rotate refresh token");
    }
  }
}

export function hashPkceVerifier(verifier: string): string {
  const digest = createHash("sha256").update(verifier).digest();
  return base64UrlEncode(digest);
}

function verifyPkce(verifier: string, challenge: string, method: PkceMethod): boolean {
  if (method !== "S256") return false;
  return hashPkceVerifier(verifier) === challenge;
}

function base64UrlEncode(buffer: Buffer): string {
  return buffer
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function generateToken(bytes = 32): string {
  return base64UrlEncode(randomBytes(bytes));
}
