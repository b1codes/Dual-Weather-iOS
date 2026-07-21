.PHONY: dev test lint format up down wait-db smoke package deploy smoke-prod

PYTHON ?= uv run python
UVICORN ?= uv run uvicorn
EMULATOR_URL ?= http://localhost:8002

up:
	docker compose up -d

down:
	docker compose down --remove-orphans

wait-db:
	@echo "Waiting for Firestore emulator at $(EMULATOR_URL)…"
	@for i in $$(seq 1 60); do \
		if curl -sf $(EMULATOR_URL) >/dev/null 2>&1; then \
			echo "Firestore emulator ready."; \
			exit 0; \
		fi; \
		sleep 1; \
	done; \
	echo "ERROR: Firestore emulator not ready after 60s. Is Docker running?"; \
	exit 1

dev: up wait-db
	DW_ENV=local PYTHONPATH=src $(UVICORN) dual_weather.main:app --reload --host 0.0.0.0 --port 8000

test: up wait-db
	uv run pytest -v

lint:
	uv run ruff check src tests

format:
	uv run ruff format src tests

smoke:
	@echo "Smoke testing localhost:8000…"
	curl -sf http://localhost:8000/health | jq .
	curl -sf -X POST http://localhost:8000/locations \
		-H "X-Dev-User-Sub: smoke-test" \
		-H "Content-Type: application/json" \
		-d '{"city":"Austin","state":"TX","latitude":30.27,"longitude":-97.74}' | jq .
	curl -sf http://localhost:8000/locations \
		-H "X-Dev-User-Sub: smoke-test" | jq .

# --- Deploy ----------------------------------------------------------

package:
	./scripts/build_lambda.sh

# Blocked until the GCP cutover: this code has no reachable database in prod.
# To restore, delete the guard below and put back:  deploy: package
#                                                   	./scripts/deploy.sh
deploy:
	@echo "ERROR: Deploys are blocked until the GCP cutover (see"
	@echo "docs/superpowers/specs/2026-07-21-firestore-local-migration-design.md §7)."
	@echo "Production Firestore is not provisioned yet."
	@exit 1

smoke-prod:
	@if [ -z "$$AUTH0_TOKEN" ]; then \
		echo "AUTH0_TOKEN env var required."; \
		exit 1; \
	fi
	@API_URL=$$(terraform -chdir=../infra/runtime output -raw api_url); \
	echo "Smoke testing $$API_URL"; \
	echo "--- /health (no auth)"; \
	curl -sf "$$API_URL/health" | jq .; \
	echo "--- POST /locations"; \
	curl -sf -X POST "$$API_URL/locations" \
		-H "Authorization: Bearer $$AUTH0_TOKEN" \
		-H "Content-Type: application/json" \
		-d '{"city":"Austin","state":"TX","latitude":30.27,"longitude":-97.74}' | jq .; \
	echo "--- GET /locations"; \
	curl -sf "$$API_URL/locations" \
		-H "Authorization: Bearer $$AUTH0_TOKEN" | jq .
