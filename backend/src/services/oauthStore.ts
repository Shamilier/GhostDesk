import { createHash, randomBytes } from "node:crypto";

export type PKCEMethod = "plain" | "S256";

export interface AuthorizationCodeRecord {
  code: string;
  clientId: string;
  userToken: string;
  redirectUri: string;
  codeChallenge: string;
  codeChallengeMethod: PKCEMethod;
  scope: string;
  createdAt: Date;
  expiresAt: Date;
  consumed: boolean;
  consumedAt?: Date;
}

export interface AccessTokenRecord {
  token: string;
  clientId: string;
  userToken: string;
  scope: string;
  plan?: string;
  referral?: string;
  createdAt: Date;
  expiresAt: Date;
}

export interface RefreshTokenRecord {
  token: string;
  clientId: string;
  userToken: string;
  scope: string;
  accessToken: string;
  createdAt: Date;
  expiresAt: Date;
  revoked: boolean;
  revokedAt?: Date;
}

export interface AuthorizationCodePayload {
  clientId: string;
  userToken: string;
  redirectUri: string;
  codeChallenge: string;
  codeChallengeMethod: PKCEMethod;
  scope?: string;
  lifetimeSeconds: number;
}

export interface AccessTokenPayload {
  clientId: string;
  userToken: string;
  scope: string;
  plan?: string;
  referral?: string;
  lifetimeSeconds: number;
}

export interface RefreshTokenPayload {
  clientId: string;
  userToken: string;
  scope: string;
  accessToken: string;
  lifetimeSeconds: number;
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

export class OAuthStore {
  private authorizationCodes = new Map<string, AuthorizationCodeRecord>();
  private accessTokens = new Map<string, AccessTokenRecord>();
  private refreshTokens = new Map<string, RefreshTokenRecord>();

  createAuthorizationCode(payload: AuthorizationCodePayload): AuthorizationCodeRecord {
    this.purgeExpired();

    const now = new Date();
    const expiresAt = new Date(now.getTime() + payload.lifetimeSeconds * 1000);
    const record: AuthorizationCodeRecord = {
      code: generateToken(24),
      clientId: payload.clientId,
      userToken: payload.userToken,
      redirectUri: payload.redirectUri,
      codeChallenge: payload.codeChallenge,
      codeChallengeMethod: payload.codeChallengeMethod,
      scope: payload.scope ?? "",
      createdAt: now,
      expiresAt,
      consumed: false,
    };

    this.authorizationCodes.set(record.code, record);
    return record;
  }

  consumeAuthorizationCode(code: string): AuthorizationCodeRecord | null {
    this.purgeExpired();
    const record = this.authorizationCodes.get(code);
    if (!record) return null;
    if (record.consumed) return null;
    if (record.expiresAt.getTime() <= Date.now()) {
      this.authorizationCodes.delete(code);
      return null;
    }

    record.consumed = true;
    record.consumedAt = new Date();
    this.authorizationCodes.set(code, record);
    return record;
  }

  peekAuthorizationCode(code: string): AuthorizationCodeRecord | null {
    this.purgeExpired();
    const record = this.authorizationCodes.get(code);
    if (!record) return null;
    if (record.expiresAt.getTime() <= Date.now()) {
      this.authorizationCodes.delete(code);
      return null;
    }
    return record;
  }

  createAccessToken(payload: AccessTokenPayload): AccessTokenRecord {
    this.purgeExpired();
    const now = new Date();
    const expiresAt = new Date(now.getTime() + payload.lifetimeSeconds * 1000);
    const record: AccessTokenRecord = {
      token: generateToken(32),
      clientId: payload.clientId,
      userToken: payload.userToken,
      scope: payload.scope,
      plan: payload.plan,
      referral: payload.referral,
      createdAt: now,
      expiresAt,
    };
    this.accessTokens.set(record.token, record);
    return record;
  }

  createRefreshToken(payload: RefreshTokenPayload): RefreshTokenRecord {
    this.purgeExpired();
    const now = new Date();
    const expiresAt = new Date(now.getTime() + payload.lifetimeSeconds * 1000);
    const record: RefreshTokenRecord = {
      token: generateToken(32),
      clientId: payload.clientId,
      userToken: payload.userToken,
      scope: payload.scope,
      accessToken: payload.accessToken,
      createdAt: now,
      expiresAt,
      revoked: false,
    };
    this.refreshTokens.set(record.token, record);
    return record;
  }

  getRefreshToken(token: string): RefreshTokenRecord | null {
    this.purgeExpired();
    const record = this.refreshTokens.get(token);
    if (!record) return null;
    if (record.revoked) return null;
    if (record.expiresAt.getTime() <= Date.now()) {
      this.refreshTokens.delete(token);
      return null;
    }
    return record;
  }

  revokeRefreshToken(token: string): void {
    const record = this.refreshTokens.get(token);
    if (!record) return;
    record.revoked = true;
    record.revokedAt = new Date();
    this.refreshTokens.set(token, record);
  }

  private purgeExpired() {
    const now = Date.now();
    for (const [code, record] of this.authorizationCodes.entries()) {
      if (record.expiresAt.getTime() <= now) {
        this.authorizationCodes.delete(code);
      }
    }
    for (const [token, record] of this.accessTokens.entries()) {
      if (record.expiresAt.getTime() <= now) {
        this.accessTokens.delete(token);
      }
    }
    for (const [token, record] of this.refreshTokens.entries()) {
      if (record.expiresAt.getTime() <= now || record.revoked) {
        this.refreshTokens.delete(token);
      }
    }
  }
}

export function hashPkceVerifier(verifier: string): string {
  const digest = createHash("sha256").update(verifier).digest();
  return base64UrlEncode(digest);
}
