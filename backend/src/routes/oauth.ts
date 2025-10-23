import type { Request, Response, Router } from "express";
import { Router as createRouter } from "express";
import {
  OAuthFlowError,
  type OAuthRepository,
} from "../services/oauthRepository.js";

interface OAuthRouterOptions {
  repository: OAuthRepository;
  readAuthKey: (req: Request) => string | null;
  logAuthUsage: (endpoint: string, token: string | null) => void;
  authorizationCodeTTLSeconds?: number;
  accessTokenTTLSeconds?: number;
  refreshTokenTTLSeconds?: number;
  defaultScope?: string;
}

const DEFAULT_CODE_TTL_SECONDS = 300; // 5 minutes
const DEFAULT_ACCESS_TTL_SECONDS = 900; // 15 minutes
const DEFAULT_REFRESH_TTL_SECONDS = 60 * 60 * 24 * 30; // 30 days

export function createOAuthRouter(options: OAuthRouterOptions): Router {
  const router = createRouter();
  const {
    repository,
    readAuthKey,
    logAuthUsage,
    authorizationCodeTTLSeconds = DEFAULT_CODE_TTL_SECONDS,
    accessTokenTTLSeconds = DEFAULT_ACCESS_TTL_SECONDS,
    refreshTokenTTLSeconds = DEFAULT_REFRESH_TTL_SECONDS,
    defaultScope = "",
  } = options;

  router.get("/authorize", (req: Request, res: Response) => {
    const userToken = readAuthKey(req);
    logAuthUsage("/oauth/authorize", userToken);

    if (!userToken) {
      return sendAuthorizeError(req, res, null, null, "invalid_request", "Missing authorization token", 401);
    }

    const responseType = getFirstQueryValue(req.query["response_type"]) ?? "code";
    const clientId = getFirstQueryValue(req.query["client_id"]);
    const redirectUri = getFirstQueryValue(req.query["redirect_uri"]);
    const codeChallenge = getFirstQueryValue(req.query["code_challenge"]);
    const codeChallengeMethod = getFirstQueryValue(req.query["code_challenge_method"]);
    const scope = getFirstQueryValue(req.query["scope"]) ?? defaultScope;
    const state = getFirstQueryValue(req.query["state"]);

    if (responseType !== "code") {
      return sendAuthorizeError(req, res, redirectUri, state, "invalid_request", "response_type must be code");
    }

    if (!clientId) {
      return sendAuthorizeError(req, res, redirectUri, state, "invalid_request", "Missing client_id");
    }

    if (!redirectUri) {
      return sendAuthorizeError(req, res, null, state, "invalid_request", "Missing redirect_uri");
    }

    if (!state) {
      return sendAuthorizeError(req, res, redirectUri, state, "invalid_request", "Missing state parameter");
    }

    if (!codeChallenge) {
      return sendAuthorizeError(req, res, redirectUri, state, "invalid_request", "Missing code_challenge");
    }

    if (!codeChallengeMethod || codeChallengeMethod.toUpperCase() !== "S256") {
      return sendAuthorizeError(req, res, redirectUri, state, "invalid_request", "Unsupported code_challenge_method");
    }

    try {
      repository.assertClientExists(clientId);
    } catch (error) {
      if (error instanceof OAuthFlowError) {
        return sendAuthorizeError(req, res, redirectUri, state, error.error, error.message, error.status);
      }
      throw error;
    }

    const allowedRedirects = repository.listRedirectUris(clientId);
    if (!allowedRedirects.includes(redirectUri)) {
      return sendAuthorizeError(req, res, null, state, "invalid_request", "redirect_uri is not registered for client");
    }

    try {
      const record = repository.createAuthorizationCode({
        userToken,
        clientId,
        redirectUri,
        codeChallenge,
        scope,
        lifetimeSeconds: authorizationCodeTTLSeconds,
      });

      const redirectURL = new URL(redirectUri);
      redirectURL.searchParams.set("code", record.code);
      redirectURL.searchParams.set("state", state);
      if (scope) {
        redirectURL.searchParams.set("scope", scope);
      }

      return res.redirect(302, redirectURL.toString());
    } catch (error) {
      if (error instanceof OAuthFlowError) {
        return sendAuthorizeError(req, res, redirectUri, state, error.error, error.message, error.status);
      }
      throw error;
    }
  });

  router.post("/token", (req: Request, res: Response) => {
    logAuthUsage("/oauth/token", null);
    const grantType = getFirstBodyValue(req.body?.grant_type) ?? "authorization_code";

    if (grantType === "authorization_code") {
      return handleAuthorizationCodeGrant(req, res);
    }

    if (grantType === "refresh_token") {
      return handleRefreshTokenGrant(req, res);
    }

    return res.status(400).json({ error: "unsupported_grant_type", error_description: "Unsupported grant_type" });
  });

  function handleAuthorizationCodeGrant(req: Request, res: Response) {
    const code = getFirstBodyValue(req.body?.code);
    const verifier = getFirstBodyValue(req.body?.code_verifier);
    const clientId = getFirstBodyValue(req.body?.client_id);
    const redirectUri = getFirstBodyValue(req.body?.redirect_uri);
    const plan = getFirstBodyValue(req.body?.plan);
    const referral = getFirstBodyValue(req.body?.referral);

    if (!code) {
      return res.status(400).json({ error: "invalid_request", error_description: "Missing code" });
    }
    if (!verifier) {
      return res.status(400).json({ error: "invalid_request", error_description: "Missing code_verifier" });
    }
    if (!clientId) {
      return res.status(400).json({ error: "invalid_request", error_description: "Missing client_id" });
    }
    if (!redirectUri) {
      return res.status(400).json({ error: "invalid_request", error_description: "Missing redirect_uri" });
    }

    try {
      const tokens = repository.redeemAuthorizationCode({
        code,
        codeVerifier: verifier,
        clientId,
        redirectUri,
        accessTokenTTLSeconds,
        refreshTokenTTLSeconds,
        plan: plan ?? undefined,
        referral: referral ?? undefined,
      });

      const expiresIn = Math.max(0, Math.round((tokens.accessTokenExpiresAt - Date.now()) / 1000));

      return res.status(200).json({
        token_type: "Bearer",
        access_token: tokens.accessToken,
        refresh_token: tokens.refreshToken,
        expires_in: expiresIn,
        scope: tokens.scope,
      });
    } catch (error) {
      if (error instanceof OAuthFlowError) {
        return res
          .status(error.status)
          .json({ error: error.error, error_description: error.message });
      }
      throw error;
    }
  }

  function handleRefreshTokenGrant(req: Request, res: Response) {
    const refreshToken = getFirstBodyValue(req.body?.refresh_token);
    const clientId = getFirstBodyValue(req.body?.client_id);

    if (!refreshToken) {
      return res.status(400).json({ error: "invalid_request", error_description: "Missing refresh_token" });
    }
    if (!clientId) {
      return res.status(400).json({ error: "invalid_request", error_description: "Missing client_id" });
    }

    try {
      const tokens = repository.rotateRefreshToken({
        refreshToken,
        clientId,
        accessTokenTTLSeconds,
        refreshTokenTTLSeconds,
      });

      const expiresIn = Math.max(0, Math.round((tokens.accessTokenExpiresAt - Date.now()) / 1000));

      return res.status(200).json({
        token_type: "Bearer",
        access_token: tokens.accessToken,
        refresh_token: tokens.refreshToken,
        expires_in: expiresIn,
        scope: tokens.scope,
      });
    } catch (error) {
      if (error instanceof OAuthFlowError) {
        return res
          .status(error.status)
          .json({ error: error.error, error_description: error.message });
      }
      throw error;
    }
  }

  return router;
}

function wantsJsonResponse(req: Request): boolean {
  const accepted = req.accepts(["json", "html", "text"]);
  return accepted === "json";
}

function sendAuthorizeError(
  req: Request,
  res: Response,
  redirectUri: string | null,
  state: string | null,
  error: string,
  description: string,
  status = 400
) {
  if (wantsJsonResponse(req) || !redirectUri) {
    return res.status(status).json({ error, error_description: description });
  }

  const redirectURL = new URL(redirectUri);
  redirectURL.searchParams.set("error", error);
  redirectURL.searchParams.set("error_description", description);
  if (state) {
    redirectURL.searchParams.set("state", state);
  }

  return res.redirect(302, redirectURL.toString());
}

function getFirstQueryValue(value: unknown): string | null {
  if (Array.isArray(value)) {
    const first = value.find((item) => typeof item === "string" && item.trim().length > 0);
    return first ? first.trim() : null;
  }
  if (typeof value === "string") {
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : null;
  }
  return null;
}

function getFirstBodyValue(value: unknown): string | null {
  if (Array.isArray(value)) {
    const first = value.find((item) => typeof item === "string" && item.trim().length > 0);
    return first ? first.trim() : null;
  }
  if (typeof value === "string") {
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : null;
  }
  if (value == null) return null;
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }
  return null;
}
