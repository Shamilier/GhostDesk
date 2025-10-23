# OAuth Clients

The GhostDesk backend currently supports the following OAuth public clients:

| Client ID          | Redirect URI                 | Notes                         |
| ------------------ | ---------------------------- | ----------------------------- |
| `ghostdesk-desktop` | `ghostdesk://auth/callback` | macOS desktop application flow |

The `/oauth/authorize` endpoint enforces the mapping above. Requests with a `redirect_uri`
that is not listed for a given `client_id` are rejected.
