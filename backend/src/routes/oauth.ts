import type { Request, Response, Router } from "express";
import { Router as createRouter } from "express";
import { hashPkceVerifier, OAuthStore, type PKCEMethod } from "../services/oauthStore.js";

export interface ClientRegistry {
  [clientId: string]: readonly string[];
}

interface OAuthRouterOptions {
  store: OAuthStore;
  clientRegistry: ClientRegistry;
  readAuthKey: (req: Request) => string | null;
  logAuthUsage: (endpoint: string, token: string | null) => void;
  authorizationCodeTTLSeconds?: number;
  accessTokenTTLSeconds?: number;
  refreshTokenTTLSeconds?: number;
  defaultScope?: string;
}

interface AuthorizeBody {
  response_type?: string;
  client_id?: string;
  redirect_uri?: string;
  code_challenge?: string;
  code_challenge_method?: string;
  scope?: string;
  state?: string;
}

interface TokenBody {
  grant_type?: string;
  code?: string;
  redirect_uri?: string;
  client_id?: string;
  code_verifier?: string;
  refresh_token?: string;
  scope?: string;
  plan?: string;
  referral?: string;
}

const DEFAULT_CODE_TTL = 300; // 5 minutes
const DEFAULT_ACCESS_TTL = 3600; // 1 hour
const DEFAULT_REFRESH_TTL = 60 * 60 * 24 * 30; // 30 days

export function createOAuthRouter(options: OAuthRouterOptions): Router {
  const router = createRouter();
  const {
    store,
    clientRegistry,
    readAuthKey,
    logAuthUsage,
    authorizationCodeTTLSeconds = DEFAULT_CODE_TTL,
    accessTokenTTLSeconds = DEFAULT_ACCESS_TTL,
    refreshTokenTTLSeconds = DEFAULT_REFRESH_TTL,
    defaultScope = "basic",
  } = options;

  router.post("/authorize", (req: Request, res: Response) => {
    const body = req.body as AuthorizeBody;
    const userToken = readAuthKey(req);
    logAuthUsage("/oauth/authorize", userToken);

    if (!userToken) {
      return res.status(401).json({ error: "Missing or invalid authorization token" });
    }

    if ((body.response_type ?? "code") !== "code") {
      return res.status(400).json({ error: "Unsupported response_type" });
    }

    const clientId = body.client_id?.trim();
    const redirectUri = body.redirect_uri?.trim();
    const codeChallenge = body.code_challenge?.trim();
    const method = normalizePkceMethod(body.code_challenge_method);

    if (!clientId) {
      return res.status(400).json({ error: "Missing client_id" });
    }

    if (!redirectUri) {
      return res.status(400).json({ error: "Missing redirect_uri" });
    }

    const allowedRedirects = clientRegistry[clientId] ?? [];
    if (!allowedRedirects.includes(redirectUri)) {
      return res.status(400).json({ error: "Invalid redirect_uri for client" });
    }

    if (!codeChallenge) {
      return res.status(400).json({ error: "Missing code_challenge" });
    }

    if (!method) {
      return res.status(400).json({ error: "Unsupported code_challenge_method" });
    }

    const scope = body.scope?.trim() ?? defaultScope;
    const codeRecord = store.createAuthorizationCode({
      clientId,
      userToken,
      redirectUri,
      codeChallenge,
      codeChallengeMethod: method,
      scope,
      lifetimeSeconds: authorizationCodeTTLSeconds,
    });

    const response = {
      code: codeRecord.code,
      expires_in: authorizationCodeTTLSeconds,
      redirect_uri: redirectUri,
      scope,
      state: body.state,
    };

    return res.status(201).json(response);
  });

  router.post("/token", (req: Request, res: Response) => {
    const body = req.body as TokenBody;
    const grantType = body.grant_type ?? "authorization_code";

    if (grantType === "authorization_code") {
      return handleAuthorizationCodeGrant();
    }

    if (grantType === "refresh_token") {
      return handleRefreshTokenGrant();
    }

    return res.status(400).json({ error: "Unsupported grant_type" });

    function handleAuthorizationCodeGrant() {
      const code = body.code?.trim();
      const verifier = body.code_verifier?.trim();
      const clientId = body.client_id?.trim();
      const redirectUri = body.redirect_uri?.trim();

      if (!code) {
        return res.status(400).json({ error: "Missing code" });
      }
      if (!verifier) {
        return res.status(400).json({ error: "Missing code_verifier" });
      }

      const codeRecord = store.peekAuthorizationCode(code);
      if (!codeRecord) {
        return res.status(400).json({ error: "Invalid or expired authorization code" });
      }

      if (codeRecord.consumed) {
        return res.status(400).json({ error: "Authorization code already used" });
      }

      if (clientId && clientId !== codeRecord.clientId) {
        return res.status(400).json({ error: "client_id mismatch" });
      }

      if (redirectUri && redirectUri !== codeRecord.redirectUri) {
        return res.status(400).json({ error: "redirect_uri mismatch" });
      }

      if (!verifyPkce(verifier, codeRecord.codeChallenge, codeRecord.codeChallengeMethod)) {
        return res.status(400).json({ error: "Invalid PKCE verifier" });
      }

      const consumed = store.consumeAuthorizationCode(code);
      if (!consumed) {
        return res.status(400).json({ error: "Authorization code already consumed" });
      }

      const scope = codeRecord.scope || defaultScope;
      const accessToken = store.createAccessToken({
        clientId: codeRecord.clientId,
        userToken: codeRecord.userToken,
        scope,
        plan: body.plan?.trim() || undefined,
        referral: body.referral?.trim() || undefined,
        lifetimeSeconds: accessTokenTTLSeconds,
      });

      const refreshToken = store.createRefreshToken({
        clientId: codeRecord.clientId,
        userToken: codeRecord.userToken,
        scope,
        accessToken: accessToken.token,
        lifetimeSeconds: refreshTokenTTLSeconds,
      });

      return res.status(200).json({
        access_token: accessToken.token,
        refresh_token: refreshToken.token,
        token_type: "Bearer",
        expires_in: Math.round((accessToken.expiresAt.getTime() - Date.now()) / 1000),
        scope,
      });
    }

    function handleRefreshTokenGrant() {
      const refreshTokenValue = body.refresh_token?.trim();
      const clientId = body.client_id?.trim();

      if (!refreshTokenValue) {
        return res.status(400).json({ error: "Missing refresh_token" });
      }

      const record = store.getRefreshToken(refreshTokenValue);
      if (!record) {
        return res.status(400).json({ error: "Invalid or expired refresh token" });
      }

      if (clientId && clientId !== record.clientId) {
        return res.status(400).json({ error: "client_id mismatch" });
      }

      store.revokeRefreshToken(refreshTokenValue);

      const accessToken = store.createAccessToken({
        clientId: record.clientId,
        userToken: record.userToken,
        scope: record.scope,
        plan: body.plan?.trim() || undefined,
        referral: body.referral?.trim() || undefined,
        lifetimeSeconds: accessTokenTTLSeconds,
      });

      const nextRefreshToken = store.createRefreshToken({
        clientId: record.clientId,
        userToken: record.userToken,
        scope: record.scope,
        accessToken: accessToken.token,
        lifetimeSeconds: refreshTokenTTLSeconds,
      });

      return res.status(200).json({
        access_token: accessToken.token,
        refresh_token: nextRefreshToken.token,
        token_type: "Bearer",
        expires_in: Math.round((accessToken.expiresAt.getTime() - Date.now()) / 1000),
        scope: record.scope,
      });
    }
  });

  return router;
}

function normalizePkceMethod(input?: string | null): PKCEMethod | null {
  if (!input) return "S256";
  const trimmed = input.trim();
  if (!trimmed) return "S256";
  if (trimmed.toUpperCase() === "S256") return "S256";
  if (trimmed.toLowerCase() === "plain") return "plain";
  return null;
}

function verifyPkce(verifier: string, challenge: string, method: PKCEMethod): boolean {
  if (method === "plain") {
    return verifier === challenge;
  }

  if (method === "S256") {
    return hashPkceVerifier(verifier) === challenge;
  }

  return false;
}
