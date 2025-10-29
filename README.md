# Ghost AI

## OAuth callback scheme

The macOS overlay client expects the OAuth redirect URI to use the custom URL
scheme `ghostai`. Ensure that the bundle registers the handler and that the
backend configuration matches the same callback:

- `mac-client/GHOSTDeskUI/GHOSTDeskUI/Info.plist` registers
  `ghostai://auth/callback` via `CFBundleURLTypes`.
- `backend/web/src/oauth.js` must list `ghostai://auth/callback` in the
  `redirectUris` for the `ghostai-desktop` client (this is already the default
  value).

Testers who validate OAuth flows should confirm that the custom scheme opens the
app successfully and that the redirect URI matches exactly `ghostai://auth/callback`.
