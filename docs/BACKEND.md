# GymMap — Backend & Production Guide

Technical reference for the billing/auth backend (`backend/server.dart`), production deployment and app release.
Back to the [project overview](../README.md).

## Android release signing (Play Store)

1. Generate an upload keystore (example):

```bash
keytool -genkeypair -v -keystore C:\keys\gymmap-upload.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. Create `android/key.properties` from [android/key.properties.example](../android/key.properties.example):

```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=upload
storeFile=C:\\keys\\gymmap-upload.jks
```

3. Build release bundle:

```bash
powershell -ExecutionPolicy Bypass -File scripts/build_app_production.ps1 -Target android-appbundle -DefineFile env/app.production.json
```

Note: if `android/key.properties` is missing, release build falls back to debug signing and should not be uploaded to Play Store.

## Billing backend (monthly subscription)

The repository includes a reference backend in `backend/server.dart` with:

- `POST /v1/billing/pix/charge` to create a Pix charge
- `POST /v1/billing/pix/confirm` for manual dev confirmation
- `POST /v1/billing/play/validate` to validate Google Play subscription purchase token
- `POST /v1/billing/pix/reconcile/:chargeId` for admin reconciliation with provider status API
- `POST /v1/webhooks/pix` for provider webhook confirmation
- `POST /v1/auth/anonymous` to create the device's anonymous account (returns JWT + `deviceSecret`; the app calls this automatically on first run)
- `POST /v1/auth/register` to create an account with `username`/`password` (with an anonymous session's Bearer token, it upgrades that account and keeps its `userId`)
- `POST /v1/auth/login` to issue JWT access token (username + password, anonymous `userId` + `deviceSecret`, or `AUTH_USERS_JSON` users)
- `GET /v1/subscriptions/:userId` to read active subscription
- `POST /v1/subscriptions/downgrade` to switch back to free
- `GET /v1/metrics` for production operational metrics (admin token)
- `GET /v1/gyms/nearby?lat=&lng=&radiusKm=` shared gym list: gyms any user already found near a point (one per OSM id, nearest first, no login; `radiusKm` 0.5–50, default 25; `limit` up to 500). The app asks this first and only queries Overpass when fewer than 5 gyms come back
- `POST /v1/gyms/locations/upsert` / `GET /v1/gyms/locations/:userId` gyms found by a user (feed the shared list)

### Run backend locally

The backend has its own `backend/pubspec.yaml` (the app no longer ships server-only packages such as `postgres` and `googleapis`):

```bash
cd backend && dart pub get && cd ..
dart run backend/server.dart
```

### Commercial production quickstart (4 steps)

1. Provision Postgres + backend:

```bash
copy .env.production.example .env.production
copy backend/.env.production.example backend/.env.production
docker compose --env-file .env.production -f docker-compose.production.yml up -d --build
```

2. Validate secrets/config before go-live:

```bash
powershell -ExecutionPolicy Bypass -File backend/scripts/validate_production_env.ps1 -EnvFile backend/.env.production
```

If using Google Play validation, inject service account JSON as base64 into env:

```bash
powershell -ExecutionPolicy Bypass -File backend/scripts/set_play_service_account.ps1 -ServiceAccountJsonPath C:\keys\play-service-account.json -PackageName com.devia.gymmap -RunValidation
```

Set backend URL + database URL in backend/app production files with one command:

```bash
powershell -ExecutionPolicy Bypass -File backend/scripts/set_go_live_urls_and_db.ps1 -BackendPublicBaseUrl https://api.seudominio.com -DatabaseUrl "postgres://user:pass@host:5432/db?sslmode=require" -RunValidation
```

3. Validate webhook integration contract/signature:

```bash
powershell -ExecutionPolicy Bypass -File backend/scripts/send_test_webhook.ps1 -BackendBaseUrl https://api.seudominio.com -ChargeId <pix_charge_id>
```

4. Build/publish app with production flags:

```bash
copy env/app.production.json.example env/app.production.json
powershell -ExecutionPolicy Bypass -File scripts/build_app_production.ps1 -Target android-appbundle -DefineFile env/app.production.json
```

Optional release gate (analyze + tests + env validation + build):

```bash
powershell -ExecutionPolicy Bypass -File scripts/release_gate_production.ps1 -Target android-appbundle
```

Optional environment variables:

- `PORT` (default: `8080`)
- `HOST` (default: `0.0.0.0`)
- `STORE_PATH` (default: `backend/data/store.json`)
- `BACKEND_PRODUCTION_MODE=true` enables strict production safeguards
- `CORS_ALLOW_ORIGIN` allowed origin used in CORS response (required in production mode, must not be `*`)
- `DATABASE_URL` Postgres URL (ex: `postgres://user:pass@host:5432/db?sslmode=require`)
- `WEBHOOK_TOKEN` validates header `X-Webhook-Token`
- `WEBHOOK_SIGNING_SECRET` active HMAC secret for webhook signature
- `WEBHOOK_SIGNING_SECRET_PREVIOUS` comma-separated previous secret(s) during rotation
- `WEBHOOK_SIGNATURE_TOLERANCE_SEC` allowed timestamp drift (default: `300`)
- `JWT_HS256_SECRET` enables JWT auth (`Authorization: Bearer <token>`) on app routes
- `JWT_ISSUER` token issuer value (default: `gymmap-backend`)
- `JWT_ACCESS_TTL_SEC` access token TTL in seconds (default: `2592000` = 30 days)
- `ADMIN_API_TOKEN` admin token (required in production for `/v1/metrics` and reconciliation route)
- `PIX_PROVIDER_MODE` (`mock` in local dev, `external` in production)
- `PIX_PROVIDER_VENDOR` (`generic` or `mercado_pago`)
- `PIX_PROVIDER_BASE_URL` provider API base URL
- `PIX_PROVIDER_API_KEY` provider API key/token
- `PIX_PROVIDER_CHARGE_PATH` provider charge path (default: `/v1/pix/charges`)
- `PIX_PROVIDER_STATUS_PATH_TEMPLATE` provider status path with `{chargeId}` placeholder
- `PIX_PROVIDER_TIMEOUT_SEC` provider request timeout in seconds (default: `12`)
- `PIX_MP_DEFAULT_PAYER_EMAIL` required when `PIX_PROVIDER_VENDOR=mercado_pago`
- `PIX_MP_NOTIFICATION_URL` optional URL sent when creating Mercado Pago payment
- `PLAY_PACKAGE_NAME` Android package for Play Billing validation (ex: `com.devia.gymmap`)
- `PLAY_SERVICE_ACCOUNT_JSON` service account JSON (single-line) for Android Publisher API
- `PLAY_SERVICE_ACCOUNT_JSON_BASE64` same credential as base64 (preferred over plain JSON env)
- `PLAY_PRODUCT_ID_SMART` product id mapped to Smart plan (default expected: `smart_mensal`)
- `PLAY_PRODUCT_ID_PRO` product id mapped to Pro plan (default expected: `pro_mensal`)
- `PLAY_PRODUCT_ID_ELITE` product id mapped to Elite plan (default expected: `elite_mensal`)
- `PLAY_BILLING_ALLOW_UNVERIFIED=true` dev-only fallback to bypass Google API validation when Play credentials are missing
- `RATE_LIMIT_REQUESTS_PER_MIN` global per-IP limit (default: `240`)
- `RATE_LIMIT_LOGIN_ATTEMPTS_PER_MIN` per-IP login limit (default: `15`)
- `RATE_LIMIT_BILLING_ATTEMPTS_PER_MIN` per-IP billing limit (default: `20`)
- `CHARGE_RETENTION_DAYS` retention days for historical charges (default: `120`)
- `WEBHOOK_RETENTION_DAYS` retention days for processed webhook events (default: `60`)
- `CROWD_REPORT_RETENTION_DAYS` retention days for crowd reports (default: `45`)
- `REQUEST_LOG_DISABLED=true` disables structured request logs
- `AUTH_USERS_JSON` login credentials map for operator accounts (ex: `{"user-001":"senha-123"}`); end users sign up through `/v1/auth/register` and their passwords are stored as PBKDF2-SHA256 hashes
- `AUTH_DEFAULT_PASSWORD` fallback password for any `userId` not present in `AUTH_USERS_JSON`

When `BACKEND_PRODUCTION_MODE=true`, startup fails if any of these are missing/misconfigured:

- `DATABASE_URL`
- `JWT_HS256_SECRET`
- `WEBHOOK_TOKEN` (required for `PIX_PROVIDER_VENDOR=generic`, optional for Mercado Pago)
- `WEBHOOK_SIGNING_SECRET`
- `CORS_ALLOW_ORIGIN` must be specific (not `*`)
- `ADMIN_API_TOKEN` (minimum 24 chars)
- `PIX_PROVIDER_MODE=external`
- `PIX_PROVIDER_VENDOR` (`generic` or `mercado_pago`)
- `PIX_PROVIDER_BASE_URL`
- `PIX_PROVIDER_API_KEY`
- `PIX_MP_DEFAULT_PAYER_EMAIL` (when using Mercado Pago)
- if Play Billing validation is configured: `PLAY_PACKAGE_NAME`, one of `PLAY_SERVICE_ACCOUNT_JSON`/`PLAY_SERVICE_ACCOUNT_JSON_BASE64`, and all `PLAY_PRODUCT_ID_*`
- `AUTH_DEFAULT_PASSWORD` must be empty

## Postgres backup and restore

Create backup with retention:

```bash
powershell -ExecutionPolicy Bypass -File backend/scripts/backup_postgres.ps1 -DatabaseUrl $env:DATABASE_URL -OutputDir backend/backups -RetentionDays 14
```

Restore from backup:

```bash
powershell -ExecutionPolicy Bypass -File backend/scripts/restore_postgres.ps1 -BackupFile backend/backups/gymmap_YYYYMMDD_HHMMSS.dump -DatabaseUrl $env:DATABASE_URL
```

## Connect Flutter app to backend

Start app with backend URL:

```bash
flutter run --dart-define PLAN_BACKEND_BASE_URL=http://10.0.2.2:8080 --dart-define PLAN_USER_ID=user-001 --dart-define PLAN_AUTH_TOKEN=<jwt>
```

Production-hardening example:

```bash
flutter run --dart-define PLAN_BACKEND_BASE_URL=https://api.seudominio.com --dart-define PLAN_AUTH_TOKEN=<jwt> --dart-define PLAN_PRODUCTION_MODE=true
```

Backend production-hardening example:

```bash
$env:BACKEND_PRODUCTION_MODE='true'
$env:DATABASE_URL='postgres://user:pass@host:5432/db?sslmode=require'
$env:JWT_HS256_SECRET='<strong-secret>'
$env:WEBHOOK_TOKEN='<webhook-token>'
$env:WEBHOOK_SIGNING_SECRET='<webhook-signing-secret>'
$env:ADMIN_API_TOKEN='<strong-admin-token>'
$env:PIX_PROVIDER_MODE='external'
$env:PIX_PROVIDER_VENDOR='mercado_pago'
$env:PIX_PROVIDER_BASE_URL='https://api.mercadopago.com'
$env:PIX_PROVIDER_API_KEY='<provider-api-key>'
$env:PIX_PROVIDER_CHARGE_PATH='/v1/payments'
$env:PIX_PROVIDER_STATUS_PATH_TEMPLATE='/v1/payments/{chargeId}'
$env:PIX_MP_DEFAULT_PAYER_EMAIL='financeiro@seudominio.com'
$env:PLAY_PACKAGE_NAME='com.devia.gymmap'
$env:PLAY_SERVICE_ACCOUNT_JSON_BASE64='<base64-service-account-json>'
$env:PLAY_PRODUCT_ID_SMART='smart_mensal'
$env:PLAY_PRODUCT_ID_PRO='pro_mensal'
$env:PLAY_PRODUCT_ID_ELITE='elite_mensal'
$env:CORS_ALLOW_ORIGIN='https://app.seudominio.com'
dart run backend/server.dart
```

You can also start without token and login inside the app:

```bash
flutter run --dart-define PLAN_BACKEND_BASE_URL=http://10.0.2.2:8080
```

Optional app auth variable:

- `PLAN_AUTH_TOKEN` JWT token sent as `Authorization` on backend requests
- `PLAN_PRODUCTION_MODE=true` disables local billing fallback and requires backend + authenticated user for paid-plan checkout
- `PLAN_PLAY_PRODUCT_ID_SMART`, `PLAN_PLAY_PRODUCT_ID_PRO`, `PLAN_PLAY_PRODUCT_ID_ELITE` override Google Play product IDs in app checkout
- `MAPLIBRE_STYLE_URL` vector map style (MapLibre Style JSON; default: OpenFreeMap liberty)
- `MAP_TILE_ATTRIBUTION` map credits, separated by `|` (default: OpenStreetMap contributors)
- `OVERPASS_API_URL` Overpass instance used to load gyms
- `NOMINATIM_BASE_URL` Nominatim instance used for address search
- `OSRM_BASE_URL` OSRM server for routes to the gym (default: `https://routing.openstreetmap.de/routed-{profile}`, where `{profile}` becomes `foot`, `bike` or `car`)
- app path for auth session: `Configuracoes de plano` -> `Entrar`
- Play Billing subscriptions renew automatically according to Google Play rules
- app warns when plan is close to expiration (last 3 days)

## Plan migration (Pix prorated)

- If user has active paid plan and changes to another paid tier, backend charges only the proportional difference for the remaining cycle.
- If proportional difference is zero or negative, migration is auto-applied without Pix payment.
- Current cycle expiration is preserved during migration.

## Login and JWT

Issue token:

```bash
curl -X POST http://127.0.0.1:8080/v1/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"userId\":\"user-001\",\"password\":\"senha-123\"}"
```

Example response:

```json
{
  "tokenType": "Bearer",
  "accessToken": "<jwt>",
  "expiresAt": "2026-04-02T19:10:00.000Z",
  "expiresInSec": 2592000,
  "userId": "user-001"
}
```

Network notes:

- Android emulator: `http://10.0.2.2:8080`
- iOS simulator: `http://127.0.0.1:8080`
- Physical device: use machine LAN IP, for example `http://192.168.0.10:8080`

## Google Play validation contract

`POST /v1/billing/play/validate`

Expected JSON body:

```json
{
  "userId": "user-001",
  "planKey": "pro",
  "productId": "pro_mensal",
  "purchaseToken": "<google_play_purchase_token>",
  "purchaseId": "<optional_order_id>"
}
```

Expected headers:

- `Authorization: Bearer <jwt>` (required when JWT is enabled)

## Production webhook contract

`POST /v1/webhooks/pix`

Expected JSON body:

```json
{
  "eventId": "evt_123",
  "chargeId": "pix_pro_...",
  "status": "paid"
}
```

Expected headers:

- `X-Webhook-Token: <token>` (if configured)
- `X-Webhook-Event-Id: <event-id>` (optional if body has `eventId`)
- `X-Webhook-Timestamp: <unix-seconds>` (required when signing enabled)
- `X-Webhook-Signature: sha256=<hex>` (required when signing enabled)

When using Mercado Pago (`PIX_PROVIDER_VENDOR=mercado_pago`), backend accepts Mercado Pago signature format:

- `x-signature: ts=...,v1=...`
- `x-request-id: ...`
- query parameter `data.id=<payment_id>`

Signature algorithm:

- message: `"<timestamp>.<raw-request-body>"`
- digest: `HMAC-SHA256(message, WEBHOOK_SIGNING_SECRET)` in lowercase hex

Secret rotation:

- Backend validates signature against active secret and previous secret(s)
- Keep old secret in `WEBHOOK_SIGNING_SECRET_PREVIOUS` during provider rollout
- After provider fully uses new secret, remove the old one

Idempotency:

- Webhook processing is idempotent by `eventId`
- Processed events are stored in `store.json` under `processedWebhookEvents`
- Replayed webhook with same `eventId` returns success with `idempotent: true`

## Production operations

- `GET /v1/metrics` requires `X-Admin-Token` (or `Authorization: Bearer <ADMIN_API_TOKEN>`) and returns uptime, route counters, memory and state counters.
- `POST /v1/billing/pix/reconcile/:chargeId` requires admin token and checks provider status API before confirming paid plans.
- Backend applies per-IP rate limiting (`429`) and structured request logs with `X-Request-Id`.
- Automatic retention sweep runs periodically and removes old charge/webhook/crowd-report records.

## Recommended production flow

1. App starts Google Play checkout and gets `purchaseToken`.
2. App sends token to backend (`POST /v1/billing/play/validate`).
3. Backend validates token in Android Publisher API and activates plan when purchase is active.
4. App reads `/v1/subscriptions/:userId`; after expiration/cancel, backend returns `free`.

Pix fallback flow (if still enabled):

1. App creates Pix charge (`/v1/billing/pix/charge`).
2. Provider sends signed webhook (`/v1/webhooks/pix`).
3. Backend marks charge as paid and activates plan for one calendar month.
4. App reads `/v1/subscriptions/:userId`; after expiration, backend returns `free`.

Note: in production mode (`BACKEND_PRODUCTION_MODE=true`), manual `POST /v1/billing/pix/confirm` is disabled.

