# Repository Guidelines

## Project Structure & Module Organization
GhostDesk includes three active codebases plus docs. `backend/ghostai-api` is the Node 18+ TypeScript API (Express, Kysely, AWS SDK) with runtime logic in `src/` and Vitest suites in `tests/`. `backend/web` hosts the session-backed OAuth portal built with Express + EJS. `backend/langing_page` delivers the Next.js 14 marketing site (`app/`, `components/`). `mac-client/GHOSTDeskUI` contains the SwiftUI overlay (`GhostAIOverlayApp`, managers, assets). See `docs/oauth-clients.md` for redirect details.

## Build, Test, and Development Commands
- API: `cd backend/ghostai-api && npm install && npm run dev` (port 8787). Run `npm run migrate` before first boot, `npm test` for Vitest + pg-mem, and set `AUTH_PROFILE_URL`, `DATABASE_URL`, plus S3 creds.
- Portal: `cd backend/web && npm install && npm run dev`; use `npm run start` for production after exporting `SESSION_SECRET` and database variables.
- Landing: `cd backend/langing_page && npm install && npm run dev`; verify with `npm run build && npm run start` and lint via `npm run lint`.
- macOS overlay: open `mac-client/GHOSTDeskUI/GHOSTDeskUI.xcodeproj` in Xcode 15+, pick `GhostAIOverlayApp`, keep the URL scheme `ghostai://auth/callback`, then press ⌘R.

## Coding Style & Naming Conventions
TypeScript files use 2-space indentation, ES modules, camelCase functions, and PascalCase React components (see `backend/ghostai-api/src/server.ts` and `backend/langing_page/components/*`). Keep Tailwind utilities inline and adjust palette variables in `app/globals.css`. Swift sources use 4-space indentation, `final class` when possible, descriptive filenames such as `OverlayInsightsPanel.swift`, and the existing property-wrapper patterns around `OverlayModel` or `UploadManager`. Configure behavior via `.env` files instead of literals.

## Testing Guidelines
Automated coverage currently lives inside `backend/ghostai-api`; add new specs under `tests/*.test.ts`, pair each endpoint change with success + failure cases, and rely on pg-mem plus AWS mocks instead of real services. Portal and landing updates should pass `npm run lint` and include manual checks for auth flows or Lighthouse regressions. The macOS overlay has no XCTest harness, so attach screen recordings that prove OAuth and recording/upload loops before review.

## Commit & Pull Request Guidelines
Recent history favors short, imperative subjects such as `Handle tutorial callout obstacles` or `Fix tutorial overlay updates after toolbar resize`; keep the first line under ~70 chars and mention the module when helpful. Reference issues via `#123` and let merge commits retain the `Merge pull request #...` format. Pull requests should list scope, environment or migration changes, UI screenshots/GIFs, and the tests or manual steps you ran, with links to supporting docs when reviewers need context.
