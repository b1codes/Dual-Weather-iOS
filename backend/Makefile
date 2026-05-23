.PHONY: dev test lint format up down init-db smoke

PYTHON ?= uv run python
UVICORN ?= uv run uvicorn

up:
	docker compose up -d

down:
	docker compose down

init-db:
	$(PYTHON) scripts/init_local_dynamo.py

dev: up init-db
	DW_ENV=local PYTHONPATH=src $(UVICORN) dual_weather.main:app --reload --host 0.0.0.0 --port 8000

test:
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
