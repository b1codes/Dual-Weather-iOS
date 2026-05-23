# Dual Weather Backend

FastAPI service that powers the Dual Weather iOS app. Runs locally via uvicorn and deploys to AWS Lambda behind API Gateway.

## Quick start

```bash
uv sync
docker compose up -d
uv run python scripts/init_local_dynamo.py
make dev
```

Then visit http://localhost:8000/docs.

See `docs/superpowers/specs/2026-05-23-backend-infra-extraction-design.md` for full design.
