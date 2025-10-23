# OAuth Clients

The GhostDesk backend currently supports the following OAuth public clients:

| Client ID          | Redirect URI                 | Notes                         |
| ------------------ | ---------------------------- | ----------------------------- |
| `ghostdesk-desktop` | `ghostdesk://auth/callback` | macOS desktop application flow |

## macOS desktop application flow

* **Authorize:** `GET /oauth/authorize`
  * Required query parameters: `response_type=code`, `client_id`, `redirect_uri`, `state`, `code_challenge`, `code_challenge_method=S256`.
  * The handler verifies the client/redirect pair and PKCE challenge, then redirects with a single-use authorization code that expires after 5 minutes.
  * Errors redirect back with `error` and `error_description` parameters (or return JSON when `Accept: application/json`).
* **Token exchange:** `POST /oauth/token` (`application/x-www-form-urlencoded`)
  * `grant_type=authorization_code` requires `code`, `code_verifier`, `client_id`, `redirect_uri`.
  * `grant_type=refresh_token` requires `refresh_token`, `client_id`.
  * Successful responses include `token_type=Bearer`, `access_token`, `refresh_token`, `expires_in` (15 minutes), and `scope`.
  * Refresh tokens rotate on every exchange, expire after 30 days, and revoked tokens are rejected if replayed.
* **API usage:** send `Authorization: Bearer <access_token>` to endpoints such as `GET /api/me`.

PKCE code challenges must use the S256 transformation. Redirect URIs are validated against the whitelist above.
