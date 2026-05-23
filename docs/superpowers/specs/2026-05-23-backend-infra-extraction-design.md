---
title: Backend & Infra Extraction Design
date: 2026-05-23
author: Brandon Lamer-Connolly
status: approved-pending-implementation-plan
---

# Backend & Infra Extraction Design

## 1. Context

The Dual Weather iOS app currently uses Firebase (Firestore only) for one feature: a shared "saved locations" collection. There is no Firebase Auth, Analytics, FCM, or Functions in use. WeatherKit is invoked entirely on-device via Apple's Swift framework.

The project is being restructured into a three-directory monorepo:

```
Dual-Weather-iOS/
├── frontend/    # SwiftUI iOS app (existing)
├── backend/     # NEW — FastAPI service that runs on AWS Lambda
└── infra/       # NEW — Terraform for AWS + Auth0 resources
```

Goals:
- Extract Firebase entirely. No remaining Firebase dependency in the iOS app.
- Replace Firestore-backed saved locations with a dedicated API service.
- Add real per-user accounts (data isolation, identity that survives reinstall).
- Stay near $0 cost while the app has no proven user base.
- Leave a clean upgrade path for a future server-side WeatherKit proxy without designing it now.

Non-goals (v1):
- Server-side WeatherKit. On-device only.
- CI/CD via GitHub Actions. Manual `terraform apply` / `make deploy` for v1.
- Multi-environment (dev/staging/prod). Single prod environment only.
- Data migration from existing Firestore. Start fresh.
- Live-AWS test suite in CI. Manual smoke testing post-deploy is sufficient.

## 2. Decision summary

| Topic | Decision |
|---|---|
| Auth | Auth0 as sole IdP. Apple Native Social connection + database (email/password) connection. |
| iOS auth SDK | `Auth0.swift` SPM package. Native `ASAuthorizationAppleIDProvider` for the Apple path, exchanged with Auth0. |
| Compute | Single AWS Lambda, Python 3.12, ARM64, FastAPI + Mangum. |
| Edge | API Gateway HTTP API with a JWT authorizer pointed at Auth0's JWKS. |
| Data | DynamoDB on-demand, single-table design, partition key = `USER#<sub>`. PITR enabled. |
| Secrets | None in v1. Lambda non-secret config travels as plain env vars. SSM Parameter Store (SecureString) is reserved for future secrets (e.g., WeatherKit `.p8`). Secrets Manager is explicitly *not* used. |
| Logs | CloudWatch Logs, 14-day retention, structured JSON via `aws-lambda-powertools`. |
| Region | `us-east-2` (Ohio). |
| WeatherKit | On-device today. `GET /weather` endpoint reserved but unimplemented. |
| Environments | Single (prod). |
| CI/CD | Manual deploy for v1 (`terraform apply`, `make deploy`). |
| Terraform layout | Three root modules: `bootstrap/`, `platform/`, `runtime/`, each with its own state file. |
| Python tooling | uv. |
| Migration | None. Start fresh. |

## 3. Architecture

### Services

| Layer | Service | Notes |
|---|---|---|
| Edge | API Gateway HTTP API | ~$1/M requests. JWT authorizer rejects unauthed traffic before Lambda. |
| Compute | Lambda (Python 3.12, ARM64) | FastAPI + Mangum. Single function for all routes. |
| Auth | Auth0 (SaaS, external) | Native iOS app, Apple + database connections. Free up to 25k MAU. |
| Data | DynamoDB on-demand | Single table, PITR enabled, no GSIs in v1. |
| Secrets | _(none in v1)_ | Non-secret config = Lambda env vars. SSM reserved for future secrets. |
| Logs | CloudWatch Logs | 14-day retention configured explicitly in Terraform. |

### Request flow

```
iOS app
  │ 1. Auth0 issues JWT (after Apple or email sign-in)
  │
  │ 2. HTTPS request with `Authorization: Bearer <Auth0 JWT>`
  ▼
API Gateway HTTP API
  │ 3. JWT authorizer validates signature + audience via Auth0 JWKS
  │ 4. Forwards request + claims context to Lambda
  ▼
Lambda (FastAPI + Mangum)
  │ 5. `current_user` dependency extracts `sub` from authorizer claims
  │ 6. Repository writes/reads DynamoDB scoped by USER#<sub>
  ▼
DynamoDB → response → Lambda → API Gateway → iOS
```

Unauthenticated or invalid-token requests are rejected at API Gateway. Lambda is never invoked for them.

### Cost model (us-east-2, monthly)

| Resource | Idle | ~100 active users, 30 req/user/day |
|---|---|---|
| Auth0 (free up to 25k MAU) | $0 | $0 |
| API Gateway HTTP API | $0 | ~$0.09 |
| Lambda (1M free requests, 400k GB-s free) | $0 | $0 (under free tier) |
| DynamoDB on-demand | $0 | < $0.05 |
| CloudWatch Logs (14-day) | < $0.10 | $0.10–$0.50 |
| **Total** | **~$0.10/mo** | **~$0.25–$0.75/mo** |

## 4. Directory layout

### `backend/`

```
backend/
├── pyproject.toml              # uv-managed
├── uv.lock
├── README.md
├── Makefile                    # `make dev`, `make test`, `make package`, `make deploy`
├── .python-version             # 3.12
├── src/
│   └── dual_weather/
│       ├── __init__.py
│       ├── main.py             # FastAPI app + Mangum handler export
│       ├── settings.py         # pydantic-settings: TABLE_NAME, AUTH0_*, LOG_LEVEL, DW_ENV
│       ├── deps.py             # FastAPI dependencies: current_user, dynamo_table
│       ├── auth.py             # Extracts sub/claims from API GW authorizer context
│       ├── routers/
│       │   ├── __init__.py
│       │   ├── health.py       # GET /health  (no auth)
│       │   ├── me.py           # GET /me      (auth)
│       │   └── locations.py    # CRUD /locations  (auth)
│       ├── repositories/
│       │   └── locations.py    # Only file that imports boto3
│       └── schemas/
│           ├── location.py     # pydantic models (LocationIn, LocationOut)
│           └── errors.py       # ProblemDetails (RFC 7807)
├── tests/
│   ├── conftest.py             # moto DynamoDB + TestClient fixtures
│   ├── test_locations.py
│   └── test_auth.py
└── scripts/
    ├── build_lambda.sh         # uv pip install --target build/ + zip
    └── deploy.sh               # reads function name from Terraform output, aws lambda update-function-code
```

Layering rules:
- Only `repositories/` imports `boto3`.
- Routers never instantiate boto3 directly; they depend on injected repositories.
- `auth.py` is the single point that knows the shape of API Gateway's authorizer claims context.
- Pydantic schemas are API-contract types; they are not the DynamoDB item shape (mapping happens in repositories).

### `infra/`

```
infra/
├── bootstrap/                  # one-time, local state
│   ├── main.tf                 # S3 state bucket (versioned, SSE), DynamoDB lock table
│   ├── outputs.tf
│   └── README.md
├── platform/                   # long-lived identity/data, remote state
│   ├── backend.tf              # remote state in the bootstrap bucket
│   ├── main.tf
│   ├── auth0.tf                # Auth0 Native iOS app, Apple connection, DB connection
│   ├── outputs.tf              # auth0_domain, auth0_native_client_id, auth0_audience
│   └── variables.tf
└── runtime/                    # disposable compute, remote state
    ├── backend.tf
    ├── main.tf
    ├── data.tf                 # terraform_remote_state -> platform outputs
    ├── dynamodb.tf
    ├── lambda.tf               # function + log group with 14-day retention
    ├── apigw.tf                # HTTP API + JWT authorizer (issuer = Auth0)
    ├── iam.tf                  # Lambda exec role + least-privilege DynamoDB policy
    ├── outputs.tf              # api_url, function_name, table_name
    └── variables.tf
```

Providers used in `platform/`:
- `hashicorp/aws`
- `auth0/auth0` (managed via `TF_VAR_auth0_api_token` env var — never committed)

The split enables `cd infra/runtime && terraform destroy` to drop compute to ~$0 without losing user identities held in Auth0 + DynamoDB.

## 5. Data model

Single DynamoDB table, on-demand billing, PITR enabled.

```
Table:  DualWeather
PK:     pk (string)
SK:     sk (string)
Billing: PAY_PER_REQUEST
```

| Entity | pk | sk | other attrs |
|---|---|---|---|
| User profile | `USER#<sub>` | `PROFILE` | `created_at`, `email?`, `display_name?` |
| Saved location | `USER#<sub>` | `LOC#<uuidv7>` | `city`, `state`, `latitude`, `longitude`, `created_at` |

`<sub>` is the Auth0 JWT `sub` claim — a stable opaque string like `apple|001234.abcdef...` or `auth0|65f3...`. The connection prefix is preserved (useful for later analytics on sign-up channel).

Access patterns supported without GSIs:
- List user's locations: `Query pk = USER#<sub> AND begins_with(sk, "LOC#")`.
- Get one location: `GetItem pk, sk`.
- Delete a location: `DeleteItem pk, sk`.
- Add a location: `PutItem` with new UUIDv7 in `sk`.

GSIs may be added later without table-level migration.

## 6. API surface

Base URL: `https://<api-id>.execute-api.us-east-2.amazonaws.com` (custom domain to add later).

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `GET` | `/health` | none | Liveness probe. Returns `{"status":"ok"}`. |
| `GET` | `/me` | JWT | Lazy provisioning. Creates profile row on first call, returns it. |
| `GET` | `/locations` | JWT | List the current user's saved locations. |
| `POST` | `/locations` | JWT | Create a saved location. Body: `{city, state, latitude, longitude}`. Returns the created item with server-assigned `id`. |
| `DELETE` | `/locations/{id}` | JWT | Delete one saved location. |
| *(future)* `GET` | `/weather` | JWT | Reserved for server-side WeatherKit proxy. Not implemented. |

### Error contract

All non-2xx responses follow [RFC 7807 Problem Details](https://datatracker.ietf.org/doc/html/rfc7807):

```json
{
  "type": "https://dualweather.app/errors/location-not-found",
  "title": "Location not found",
  "status": 404,
  "detail": "No saved location with id 01HXYZ... for this user."
}
```

A single FastAPI exception handler in `main.py` converts `HTTPException` and validation errors into this shape.

## 7. Auth flow

```
                          ┌────────────────────────────────┐
   ┌─ iOS app ──┐         │  Auth0 tenant (SaaS)           │
   │            │         │                                │
   │ Path A:    │         │  Native iOS Application:       │
   │ [Apple]    │ ───────►│   - Apple Native Social conn.  │
   │ ASAuth-    │ Apple   │   - Database conn. (email)     │
   │ AppleID    │ auth    │                                │
   │ Provider   │ code    │  Issues:                       │
   │            │ ◄────── │   - id_token  (RS256 JWT)      │
   │            │         │   - access_token               │
   │ Path B:    │         │   - refresh_token              │
   │ [Email]    │ ───────►│                                │
   │ Auth0      │ Univ.   │  /.well-known/jwks.json        │
   │ webAuth()  │ Login   │  /.well-known/openid-config…   │
   └────┬───────┘         └────────────────────────────────┘
        │ HTTPS + Bearer <access_token>
        ▼
   API Gateway JWT authorizer
   issuer = https://<tenant>.auth0.com/
   audience = https://api.dualweather/
        │
        ▼
   Lambda + FastAPI
   current_user(request) → claims["sub"]
```

### iOS side

- Apple path: native `ASAuthorizationAppleIDProvider` is run first (per App Store Guideline 4.8 and Auth0 Native Social rules). The resulting `authorizationCode` is exchanged with Auth0 via `Auth0.authentication().login(appleAuthorizationCode:fullName:)`.
- Email path: `Auth0.webAuth().start()` opens Auth0's Universal Login.
- Refresh tokens stored via Auth0.swift's `CredentialsManager`, which writes to the iOS Keychain.
- Access token attached as `Authorization: Bearer ...` to every API call. Refreshed by `CredentialsManager` when expired.

### API Gateway side

- One `JWT_AUTHORIZER` resource pointed at Auth0's discovery URL.
- The configured `audience` matches the Auth0 API identifier (`https://api.dualweather/`). This is what causes Auth0 to issue an RS256 JWT rather than an opaque token.
- API Gateway rejects unauthenticated or invalid-token requests with a 401 directly; Lambda is not invoked.

### FastAPI side

- Mangum exposes API Gateway's authorizer claims at `event.requestContext.authorizer.jwt.claims`.
- `deps.py::current_user(request) -> User` extracts `claims["sub"]`. Every authed router declares `user: User = Depends(current_user)`.
- The repository layer accepts `user_sub` as its first argument; it never trusts a user id from the request body.

Sign-in-with-Apple subtlety: Apple's real email (where applicable) is only returned in the **first** sign-in. `GET /me`'s lazy-provisioning handler must persist whatever email it receives on the first call.

## 8. iOS changes

### Removed

| File | Action |
|---|---|
| `Dual_Weather_iOSApp.swift` | Remove `import FirebaseCore`, `AppDelegate`, `FirebaseApp.configure()`. Add Auth0 configuration. |
| `GoogleService-Info.plist` | Delete file. Remove from Xcode target. |
| `Services and Managers/DatabaseManager.swift` | Delete entirely. |
| `Components/SearchCard.swift` | Drop Firestore imports + `addToFirestore()`. Call new API client. |
| `Tabs/SavedLocationsView.swift` | Drop Firestore imports + `Firestore.firestore()`. Call new API client. |
| `Package.resolved` | Remove `firebase-ios-sdk`. Add `Auth0.swift`. |

### Added

| File / change | Purpose |
|---|---|
| `Services and Managers/APIClient.swift` | Thin `URLSession` wrapper; auto-injects Auth0 access token; decodes Problem Details. |
| `Services and Managers/AuthService.swift` | Wraps Auth0.swift. Published `authState`. Exposes `signInWithApple()`, `signInWithEmail()`, `signOut()`. |
| `Services and Managers/LocationsRepository.swift` | Typed methods: `list()`, `create(_:)`, `delete(id:)`. Mirrors old `DatabaseManager` signatures so views barely change. |
| `Tabs/SignInView.swift` | Shown when `authState == .signedOut`. Apple button on top, "Continue with email" below. |
| `Dual_Weather_iOS.entitlements` | Add Sign in with Apple capability. |
| `Config.xcconfig` | Add `DW_API_BASE_URL`, `DW_AUTH0_DOMAIN`, `DW_AUTH0_CLIENT_ID`, `DW_AUTH0_AUDIENCE`. |

User-facing flow: sign in via Apple (recommended button) or email (secondary button), then the existing `TabUIView` appears unchanged. WeatherKit still loads on-device. The saved-locations and search views look visually identical; only the storage call site changes.

## 9. Local development

The backend is fully runnable without AWS.

### Backend

```
cd backend
uv sync
make dev                                  # uvicorn src.dual_weather.main:app --reload → :8000
docker run -p 8001:8000 amazon/dynamodb-local
python scripts/init_local_dynamo.py       # creates the DualWeather table locally
```

Settings detect `DW_ENV=local` and point boto3 at `http://localhost:8001`.

### Local auth bypass

When `DW_ENV=local`, the `current_user` FastAPI dependency accepts an `X-Dev-User-Sub: <any-string>` header in lieu of a JWT. The branch is guarded by an `if settings.env == "local":` check; it is unreachable in any other environment.

### Tests

```
make test
```

Uses [moto](https://github.com/getmoto/moto) for in-memory DynamoDB. FastAPI `TestClient` exercises routes end-to-end without AWS.

### iOS against local backend

A debug-only xcconfig overrides `DW_API_BASE_URL` to `http://localhost:8000`. Sign-in continues to use real Auth0 (Auth0 isn't easily mockable on-device, and the cost is the same on the free tier).

## 10. Build sequence (milestones)

| # | Milestone | Verifiable output |
|---|---|---|
| 1 | Repo restructure | `frontend/`, `backend/`, `infra/` exist. CLAUDE.md / agent.md updated. |
| 2 | Bootstrap Terraform state | `infra/bootstrap` applied. S3 state bucket + Dynamo lock table exist. |
| 3 | Backend Python skeleton | `uv sync && make dev` serves FastAPI on :8000. `/health` works. No AWS deps. |
| 4 | Local DynamoDB + repository layer | `LocationRepository` tests pass against local Dynamo. `POST` / `GET /locations` work locally via `X-Dev-User-Sub`. |
| 5 | Auth0 tenant + Terraform Auth0 provider | `infra/platform` applied. Auth0 dashboard shows the Native iOS app, Apple + database connections. |
| 6 | Runtime stack deployed | `infra/runtime` applied. `curl /health` returns 200. `curl /locations` without token returns 401 from API GW. |
| 7 | Backend deployed to Lambda | `make package && make deploy` uploads zip. Authenticated curl hits `/locations` end-to-end. |
| 8 | iOS Firebase removal + Auth0 wiring | `frontend/` builds with no Firebase refs. Sign-in-with-Apple completes; Auth0 JWT in Keychain. |
| 9 | iOS LocationsRepository wired to API | `SavedLocationsView` and `SearchCard` use the API. Save / list / delete work on a device. |
| 10 | Cutover cleanup | Firebase project decommissioned. `GoogleService-Info.plist`, `DatabaseManager.swift`, `firebase-ios-sdk` removed. |

Milestones 3–4 are AWS-free. Milestone 5 must precede milestone 6 (the JWT authorizer in `runtime/` consumes Auth0 outputs from `platform/`). Milestone 8 is the first non-revertable step from a release perspective.

## 11. Observability

- **Logs**: CloudWatch Logs, 14-day retention enforced in Terraform. JSON-structured via `aws-lambda-powertools` Logger. Each log entry includes `request_id`, `user_sub`, `path`, `method`, `status_code`, `duration_ms`.
- **Metrics**: API Gateway and Lambda auto-emit standard CloudWatch metrics. No custom metrics in v1.
- **Alarms (v1)**: a single CloudWatch Alarm — `Lambda 5XXError > 5 in 5 minutes` → SNS topic → email.
- **No X-Ray** in v1.
- **No third-party log shipping** in v1.

## 12. Testing

```
manual smoke curl against deployed stack          (small, post-deploy)
integration tests: FastAPI TestClient + moto      (most coverage)
unit tests: schemas, repositories, auth.py        (largest layer)
```

- moto provides in-memory DynamoDB for tests.
- The `X-Dev-User-Sub` bypass enables integration tests of authed routes without minting real JWTs.
- Cross-user isolation is tested explicitly (user A's request must not see user B's data).
- No live-AWS test suite in CI for v1. A manual smoke curl after each deploy is the contract.

## 13. Open questions / deferred work

These are explicitly out of scope for the first implementation pass and should remain so unless re-prioritized:

- **Custom domain** for the API (Route 53 + ACM cert + API GW custom domain mapping). Not required while the autogenerated `execute-api` URL works.
- **Server-side WeatherKit proxy**. The `/weather` slot is reserved; implementing it requires Secrets Manager-or-SSM storage for the `.p8`, JWT signing in Lambda, and an in-DynamoDB weather cache.
- **CI/CD via GitHub Actions** with OIDC into AWS.
- **Multi-environment (dev/staging)** Terraform workspaces.
- **Settings tab** in the iOS app (to host sign-out, units preference, etc.). Sign-out is required functionally but the UI for it is unspecified in v1.
- **KMS-encrypted DynamoDB** with a customer-managed key. Default AWS-managed key is acceptable for v1.
- **Synthetic canary** or Route 53 health check on `/health`.

## 14. Reference

- [Auth0 Native Social: Apple](https://auth0.com/docs/authenticate/identity-providers/social-identity-providers/apple-native)
- [API Gateway HTTP API JWT authorizer](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-jwt-authorizer.html)
- [AWS Lambda Powertools for Python — Logger](https://docs.powertools.aws.dev/lambda/python/latest/core/logger/)
- [Mangum](https://mangum.io/) — ASGI adapter for AWS Lambda
- [moto](https://github.com/getmoto/moto) — AWS mocking for tests
- [RFC 7807 — Problem Details for HTTP APIs](https://datatracker.ietf.org/doc/html/rfc7807)
