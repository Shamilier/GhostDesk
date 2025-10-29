# OAuth Clients

The Ghost AI backend currently supports the following OAuth public clients:

| Client ID         | Redirect URI                | Notes                         |
| ----------------- | --------------------------- | ----------------------------- |
| `ghostai-desktop` | `ghostai://auth/callback` | macOS desktop application flow |

The `/oauth/authorize` endpoint enforces the mapping above. Requests with a `redirect_uri`
that is not listed for a given `client_id` are rejected.

## Authorization Code + PKCE Flow

Ghost AI использует стандартный Authorization Code Grant с обязательной проверкой PKCE (`S256`).

### 1. Инициализация авторизации

`GET /oauth/authorize`

Обязательные параметры запроса:

- `response_type=code`
- `client_id`
- `redirect_uri`
- `code_challenge`
- `code_challenge_method=S256`
- `state` — рекомендуется для защиты от CSRF (возвращается без изменений).

Если пользователь не авторизован в портале, он перенаправляется на `/login`, где параметры автоматически прокидываются через скрытые поля формы. После успешного входа или регистрации портал выдаёт authorization code и редиректит пользователя обратно на `redirect_uri` с параметрами `code` и `state`.

### 2. Обмен кода на токены

`POST /oauth/token`

- `grant_type=authorization_code`
- `client_id`
- `code`
- `redirect_uri`
- `code_verifier`

PKCE проверяется как `base64url(SHA256(code_verifier)) === code_challenge`. В ответе возвращается JSON:

```json
{
  "access_token": "<bearer token>",
  "refresh_token": "<refresh token>",
  "expires_in": 3600,
  "token_type": "bearer"
}
```

Refresh-токены можно обновлять через `grant_type=refresh_token` с тем же `client_id`. При обновлении предыдущий refresh-токен отзывается.

### 3. Отзыв токенов

`POST /oauth/revoke`

- `client_id`
- `token` (refresh token)
- `token_type_hint=refresh_token` (опционально, но рекомендовано)

### 4. Получение профиля

`GET /oauth/profile`

- Требует заголовок `Authorization: Bearer <access_token>`.
- В ответе содержатся `email`, `plan`, `referral`, `created_at` и пользовательский API-токен из портала.

### Срок действия и хранение

- Authorization code — 10 минут.
- Access token — 1 час.
- Refresh token — 30 дней.

Все значения кодов и токенов сохраняются как SHA-256 хэши в SQLite. Это позволяет безопасно отозвать или проверить токен без хранения исходного значения.
