# Auth setup (Phase 1 accounts)

## Backend environment

| Variable | Required | Purpose |
| --- | --- | --- |
| `AUTH_SECRET` | Production: **required** — the server refuses to start without it | HS256 key that signs session JWTs. Generate with `openssl rand -base64 48`. |
| `GOOGLE_CLIENT_ID` | Required for Google sign-in | Web/server OAuth client ID. When set, `POST /api/auth/google` rejects any ID token whose audience (`aud`) does not match; without it the audience is unverified (a warning is logged). |

Add both to `.env.local` (copied from `.env.example`). Note: in production deployments without
`AUTH_SECRET`, `lib/auth.ts` throws at import time by design — a missing signing key must fail a
deploy instead of shipping an instance that accepts forged tokens.

## Google Sign-In platform setup

The mobile client uses `google_sign_in` (v7 API).

1. In Google Cloud Console (or Firebase), create an OAuth 2.0 **Web application** client — this is
   the *server* client ID used as the ID token audience.
2. Backend: set that web client ID as `GOOGLE_CLIENT_ID`.
3. Mobile: pass the same web client ID, e.g. at build time:
   `flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>` (see
   `lib/core/constants/api_constants.dart`).
4. Android: register the app package name + signing cert SHA-1 with the project, or ship a
   `google-services.json` containing a web OAuth client (`client_type: 3`).
5. iOS: add `GIDClientID` and the reversed client ID URL scheme to `ios/Runner/Info.plist`.

Without steps 4–5 the plugin surfaces a configuration error at authenticate time; the auth sheet
shows that error instead of a fake token, and the Google button stays functional (no crash) once
IDs are configured.

## Rate limits

| Endpoint | Limit |
| --- | --- |
| `POST /api/auth/register` | 10/min per client |
| `POST /api/auth/login` | 10/min per client **and** 8/min per account |
| `POST /api/auth/google` | 15/min per client |
| `GET /api/auth/me` | 30/min per client |

`x-forwarded-for` (first hop) wins, then `x-real-ip`; with no trusted proxy every client shares an
`unknown-local` bucket, so production must run behind a proxy that sets one of these headers.
