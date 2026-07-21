# Dual Weather Backend

FastAPI service that powers the Dual Weather iOS app. Runs locally via uvicorn and deploys to AWS Lambda behind API Gateway.

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

> **Deploys are blocked.** Production Firestore is not provisioned yet, so
> `make deploy` intentionally fails. The already-deployed Lambda is unaffected.
> See `docs/superpowers/specs/2026-07-21-firestore-local-migration-design.md` §7.

See `docs/superpowers/specs/2026-05-23-backend-infra-extraction-design.md` for full design.
