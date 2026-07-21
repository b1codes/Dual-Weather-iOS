# Dual Weather Backend

FastAPI service that powers the Dual Weather iOS app. It currently runs locally,
via uvicorn, against a Firestore emulator; deploys are blocked pending the GCP
cutover (see below).

## Prerequisites

Docker must be running before `make dev` or `make test` — both bring up a
Firestore emulator container via `docker compose`, and without Docker running
that step fails.

## Quick start

```bash
uv sync
make dev
```

Then visit http://localhost:8000/docs.

Local development runs against the **Firestore emulator** (Docker, port 8002).
`make dev` and `make test` start it and wait for readiness automatically. No GCP
account or credentials are required — `FIRESTORE_EMULATOR_HOST` makes the client
bypass auth entirely.

The emulator image is large, so the first `make up` involves a slow one-time pull.

`Settings.env` defaults to `"prod"`, so running the app any other way than
`make dev` (e.g. `uv run uvicorn dual_weather.main:app` directly) requires
setting `DW_ENV=local` yourself, or you'll hit a `RuntimeError` about
Firestore not being available — that error means the env var is missing, not
that infrastructure is broken.

> **Deploys are blocked.** Production Firestore is not provisioned yet, so
> `make deploy` intentionally fails. The already-deployed Lambda is unaffected.
> See `docs/superpowers/specs/2026-07-21-firestore-local-migration-design.md` §7.

See `docs/superpowers/specs/2026-05-23-backend-infra-extraction-design.md` for full design.
