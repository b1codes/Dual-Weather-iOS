# Firestore Local Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all DynamoDB access in the `backend/` FastAPI service with Firestore, running entirely against the Firestore emulator so no GCP account or credentials are required.

**Architecture:** The dependency-injection seam already in place does the work. Routers depend on `LocationsRepository` via FastAPI's `Depends`, and only two modules ever touch boto3 (`dynamo.py` and `repositories/locations.py`). We add a Firestore client factory mirroring `dynamo.py`'s shape, rewrite the repository's internals while keeping its filename and class name, then delete the DynamoDB code. The single-table `pk`/`sk` design becomes Firestore subcollections at `users/{sub}/locations/{id}`.

**Tech Stack:** Python 3.12, FastAPI, Pydantic v2, `pydantic-settings`, `google-cloud-firestore`, pytest, Docker Compose, uv.

**Spec:** `docs/superpowers/specs/2026-07-21-firestore-local-migration-design.md`
**Ticket:** https://app.clickup.com/t/86bb077qy

## Global Constraints

- All work happens in `backend/`. **`infra/` and `frontend/` must not be modified by any task.** The DynamoDB table has `prevent_destroy = true` and is referenced by `infra/runtime/lambda.tf` and `infra/runtime/iam.tf`; its teardown belongs to the later GCP cutover ticket.
- **Never run `make deploy`.** Deploys are blocked until the GCP cutover. The already-deployed Lambda runs the zip stored in AWS and is unaffected by this work.
- The HTTP API contract must not change. `LocationOut` keeps `id`, `city`, `state`, `latitude` (float), `longitude` (float), `created_at`. The iOS app is untouched.
- Emulator image is pinned: `gcr.io/google.com/cloudsdktool/google-cloud-cli:577.0.0-emulators`, host port **8002** (DynamoDB Local used 8001).
- Firestore dependency pin: `google-cloud-firestore>=2.28.0,<3`. Matches the repo's existing range-pin convention.
- Line length is 100 (`ruff`, configured in `pyproject.toml`). Lint with `uv run ruff check src tests` before every commit.
- Settings env vars are prefixed `DW_`. `FIRESTORE_EMULATOR_HOST` is the one exception — it is read by `google-cloud-firestore` itself and is therefore unprefixed.
- **The test suite must pass at the end of every task.** `boto3` and `moto` stay installed until Task 4 for exactly this reason.

---

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `backend/compose.yaml` | Runs the Firestore emulator | 1 |
| `backend/Makefile` | `up` / `wait-db` / `dev` / `test` / `deploy` targets | 1, 4 |
| `backend/pyproject.toml` | Dependency set | 1, 4 |
| `backend/src/dual_weather/firestore.py` | **Only** module constructing a Firestore client | 2 |
| `backend/src/dual_weather/settings.py` | Configuration | 2, 4 |
| `backend/src/dual_weather/repositories/locations.py` | Firestore persistence for profiles + locations | 3 |
| `backend/src/dual_weather/deps.py` | Wires the client into the repository | 3 |
| `backend/tests/conftest.py` | `firestore_db` fixture, per-test project isolation | 3, 4 |
| `backend/src/dual_weather/dynamo.py` | **deleted** | 4 |
| `backend/scripts/init_local_dynamo.py` | **deleted** | 4 |
| `backend/tests/test_dynamo.py` | **deleted** | 4 |

---

### Task 1: Firestore emulator running

Stands up the emulator and adds the client library. No application code changes, so the existing suite must stay green — this task is purely infrastructure.

**Files:**
- Modify: `backend/compose.yaml` (replace the whole file)
- Modify: `backend/Makefile:1-16` (targets `up` through `dev`)
- Modify: `backend/pyproject.toml:5-13` (dependencies)

**Interfaces:**
- Consumes: nothing
- Produces: a Firestore emulator reachable at `localhost:8002`; `make wait-db` blocks until it is ready; `google.cloud.firestore` importable

- [ ] **Step 1: Replace the Compose service**

Replace the entire contents of `backend/compose.yaml`:

```yaml
services:
  firestore-emulator:
    image: gcr.io/google.com/cloudsdktool/google-cloud-cli:577.0.0-emulators
    container_name: dual-weather-firestore
    ports:
      - "8002:8080"
    command: >
      gcloud emulators firestore start
      --host-port=0.0.0.0:8080
```

Note: the emulator image is much larger than `dynamodb-local` was, so the first `docker compose up -d` on a machine involves a slow pull (several hundred MB). This is a one-time cost.

- [ ] **Step 2: Add the `wait-db` target to the Makefile**

In `backend/Makefile`, add `EMULATOR_URL` near the top (after the `UVICORN ?=` line) and add `wait-db` to the `.PHONY` list:

```make
.PHONY: dev test lint format up down wait-db smoke package deploy smoke-prod

PYTHON ?= uv run python
UVICORN ?= uv run uvicorn
EMULATOR_URL ?= http://localhost:8002
```

Then add the `wait-db` target immediately after the `down` target:

```make
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
```

This polls with a bounded timeout rather than a fixed `sleep`, so a failure produces a clear message instead of a confusing connection error.

- [ ] **Step 3: Add the Firestore dependency**

In `backend/pyproject.toml`, add one line to the `dependencies` list (keep everything else as-is for now — `boto3` is still needed until Task 4):

```toml
dependencies = [
    "fastapi>=0.115.0,<0.116",
    "mangum>=0.19.0,<0.20",
    "pydantic>=2.9.0,<3",
    "pydantic-settings>=2.5.0,<3",
    "boto3>=1.35.0,<2",
    "google-cloud-firestore>=2.28.0,<3",
    "aws-lambda-powertools[parser]>=3.4.0,<4",
]
```

- [ ] **Step 4: Install and start the emulator**

Run:
```bash
cd backend && uv sync && make up && make wait-db
```
Expected: uv resolves and installs `google-cloud-firestore`; Docker pulls the image (slow first time); output ends with `Firestore emulator ready.`

- [ ] **Step 5: Verify the client library can reach the emulator**

Run:
```bash
cd backend && FIRESTORE_EMULATOR_HOST=localhost:8002 uv run python -c "
from google.cloud import firestore
from google.auth.credentials import AnonymousCredentials
c = firestore.Client(project='smoke-test', credentials=AnonymousCredentials())
c.collection('ping').document('d').set({'ok': True})
print('round-trip:', c.collection('ping').document('d').get().to_dict())
"
```
Expected: `round-trip: {'ok': True}`

- [ ] **Step 6: Confirm the existing suite is still green**

Run: `cd backend && uv run pytest -q`
Expected: all tests pass. No application code changed in this task.

- [ ] **Step 7: Commit**

```bash
git add backend/compose.yaml backend/Makefile backend/pyproject.toml backend/uv.lock
git commit -m "build: run Firestore emulator and add google-cloud-firestore"
```

---

### Task 2: Firestore client factory

Adds `firestore.py` — the only module that constructs a client — plus the settings it reads. The DynamoDB settings stay in place so nothing breaks yet.

**Files:**
- Create: `backend/src/dual_weather/firestore.py`
- Create: `backend/tests/test_firestore.py`
- Modify: `backend/src/dual_weather/settings.py:21` (add `gcp_project`), `:30-33` (add `firestore_emulator_host` property)

**Interfaces:**
- Consumes: emulator at `localhost:8002` from Task 1
- Produces:
  - `Settings.gcp_project: str` (default `"dual-weather-local"`)
  - `Settings.firestore_emulator_host: str | None` (property — `"localhost:8002"` when `is_local`, else `None`)
  - `build_client(project: str, emulator_host: str | None) -> google.cloud.firestore.Client`
  - `get_client(settings: Settings) -> google.cloud.firestore.Client` (cached; raises `RuntimeError` when misconfigured for prod)

- [ ] **Step 1: Write the failing tests**

Create `backend/tests/test_firestore.py`:

```python
import pytest

from dual_weather.firestore import build_client, get_client
from dual_weather.settings import Settings


def test_build_client_uses_emulator_host(monkeypatch):
    monkeypatch.delenv("FIRESTORE_EMULATOR_HOST", raising=False)

    client = build_client("proj-a", "localhost:8002")

    assert client.project == "proj-a"
    # Round-trip proves we really reached the emulator, not real Firestore.
    client.collection("probe").document("d1").set({"n": 1})
    assert client.collection("probe").document("d1").get().to_dict() == {"n": 1}


def test_get_client_reads_settings(monkeypatch):
    monkeypatch.setenv("DW_ENV", "local")
    monkeypatch.setenv("DW_GCP_PROJECT", "proj-b")

    client = get_client(Settings())

    assert client.project == "proj-b"


def test_get_client_rejects_unconfigured_prod(monkeypatch):
    monkeypatch.setenv("DW_ENV", "prod")
    monkeypatch.delenv("DW_GCP_PROJECT", raising=False)

    with pytest.raises(RuntimeError, match="GCP cutover"):
        get_client(Settings())


def test_settings_emulator_host_local(monkeypatch):
    monkeypatch.setenv("DW_ENV", "local")
    assert Settings().firestore_emulator_host == "localhost:8002"


def test_settings_emulator_host_prod_is_none(monkeypatch):
    monkeypatch.setenv("DW_ENV", "prod")
    assert Settings().firestore_emulator_host is None
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && uv run pytest tests/test_firestore.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'dual_weather.firestore'`

- [ ] **Step 3: Add the new settings**

In `backend/src/dual_weather/settings.py`, add `gcp_project` to the field block (leave `table_name` alone — Task 4 removes it):

```python
    env: Literal["local", "prod"] = "prod"
    table_name: str = "DualWeather"
    gcp_project: str = "dual-weather-local"
    log_level: str = "INFO"
```

Then add this property directly below the existing `dynamo_endpoint_url` property:

```python
    @property
    def firestore_emulator_host(self) -> str | None:
        return "localhost:8002" if self.is_local else None
```

- [ ] **Step 4: Write the client factory**

Create `backend/src/dual_weather/firestore.py`:

```python
"""Firestore client factory.

The only place in the codebase that constructs a Firestore client. Local runs
and the test suite talk to the Firestore emulator; setting FIRESTORE_EMULATOR_HOST
makes google-cloud-firestore skip credential discovery entirely, which is why no
GCP account or service-account key is needed anywhere in this codebase yet.
"""

from __future__ import annotations

import os
from functools import lru_cache
from typing import TYPE_CHECKING

from google.auth.credentials import AnonymousCredentials
from google.cloud import firestore

if TYPE_CHECKING:
    from dual_weather.settings import Settings

_UNCONFIGURED_PROJECT = "dual-weather-local"


def build_client(project: str, emulator_host: str | None) -> firestore.Client:
    """Construct a client. With an emulator host, auth is bypassed entirely."""
    if emulator_host is not None:
        os.environ["FIRESTORE_EMULATOR_HOST"] = emulator_host
        return firestore.Client(project=project, credentials=AnonymousCredentials())
    return firestore.Client(project=project)


@lru_cache(maxsize=1)
def _cached_client(project: str, emulator_host: str | None) -> firestore.Client:
    return build_client(project, emulator_host)


def get_client(settings: Settings) -> firestore.Client:
    """Return the shared Firestore client for the configured project."""
    if not settings.is_local and settings.gcp_project == _UNCONFIGURED_PROJECT:
        raise RuntimeError(
            "DW_GCP_PROJECT is still the local default in a non-local environment. "
            "Production Firestore is not provisioned yet — this is expected until "
            "the GCP cutover ticket lands. Do not deploy."
        )
    return _cached_client(settings.gcp_project, settings.firestore_emulator_host)
```

The explicit `RuntimeError` is what turns an opaque Application Default Credentials stack trace into an actionable message. It is the guard described in §7 of the spec.

Note that `build_client` mutates `os.environ` — `google-cloud-firestore` reads `FIRESTORE_EMULATOR_HOST` from the process environment, so there is no way to pass it per-client. This is safe here because the emulator path and the prod path never coexist in one process, but it is why `build_client` takes the host as an explicit argument rather than reading settings itself: the test fixture needs to build clients for many different projects without touching global settings.

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd backend && make wait-db && uv run pytest tests/test_firestore.py -v`
Expected: 5 passed

- [ ] **Step 6: Run the full suite and lint**

Run: `cd backend && uv run pytest -q && uv run ruff check src tests`
Expected: all tests pass, no lint errors. The DynamoDB tests are untouched and still green.

- [ ] **Step 7: Commit**

```bash
git add backend/src/dual_weather/firestore.py backend/src/dual_weather/settings.py backend/tests/test_firestore.py
git commit -m "feat: add Firestore client factory with prod misconfiguration guard"
```

---

### Task 3: Rewrite the repository for Firestore

The core of the migration. The repository, the test fixture, and `deps.py` must change together — the store cannot be half-swapped, because the API tests construct `LocationsRepository` directly.

**Files:**
- Modify: `backend/src/dual_weather/repositories/locations.py` (replace the whole file)
- Modify: `backend/src/dual_weather/deps.py` (replace the whole file)
- Modify: `backend/tests/conftest.py` (add `firestore_db`, keep `moto_dynamo` for now)
- Modify: `backend/tests/test_locations_repository.py:1-8` (fixture) and append new tests
- Modify: `backend/tests/test_locations_api.py:1-12` (fixture wiring)
- Modify: `backend/tests/test_me_api.py:1-11` and `:29-31` (fixture wiring)

**Interfaces:**
- Consumes: `get_client(settings)` and `build_client(project, emulator_host)` from Task 2
- Produces: `LocationsRepository(client=<firestore.Client>)` — same class name and module path as before, with methods unchanged in signature:
  - `get_or_create_profile(*, user_sub: str, email: str | None = None) -> UserProfile`
  - `create(*, user_sub: str, city: str, state: str, latitude: float, longitude: float) -> LocationOut`
  - `list(*, user_sub: str) -> list[LocationOut]`
  - `delete(*, user_sub: str, location_id: str) -> None` (raises `KeyError` if absent)

- [ ] **Step 1: Add the `firestore_db` fixture**

In `backend/tests/conftest.py`, add these imports at the top and append the fixture. Leave `moto_dynamo` and the `settings` fixture in place — Task 4 removes them.

```python
import uuid

from dual_weather.firestore import build_client


@pytest.fixture
def firestore_db():
    """A Firestore client bound to a project ID unique to this test.

    The emulator partitions data by project, so a fresh project ID gives complete
    isolation with no inter-test cleanup — cheaper and less error-prone than
    deleting collections between tests.
    """
    project = f"test-{uuid.uuid4().hex[:12]}"
    client = build_client(project, "localhost:8002")
    yield client
    client.close()
```

- [ ] **Step 2: Point the repository tests at Firestore and add hazard coverage**

In `backend/tests/test_locations_repository.py`, replace the fixture at the top:

```python
import pytest

from dual_weather.repositories.locations import LocationsRepository


@pytest.fixture
def repo(firestore_db):
    return LocationsRepository(client=firestore_db)
```

Leave all six existing tests exactly as written — they are the proof the contract survived. Then append these three, covering the hazards from spec §4:

```python
def test_coordinates_round_trip_as_floats(repo):
    created = repo.create(
        user_sub="u",
        city="Austin",
        state="TX",
        latitude=30.266666,
        longitude=-97.733330,
    )

    listed = repo.list(user_sub="u")[0]

    assert isinstance(listed.latitude, float)
    assert isinstance(listed.longitude, float)
    assert listed.latitude == pytest.approx(30.266666)
    assert listed.longitude == pytest.approx(-97.733330)
    assert created.longitude == listed.longitude


def test_profile_is_created_once_and_reread(repo):
    first = repo.get_or_create_profile(user_sub="apple|p", email="a@b.com")
    second = repo.get_or_create_profile(user_sub="apple|p")

    assert first.created_at == second.created_at
    assert second.email == "a@b.com"


def test_list_is_empty_for_user_with_profile_but_no_locations(repo):
    repo.get_or_create_profile(user_sub="apple|lonely")

    assert repo.list(user_sub="apple|lonely") == []
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd backend && make wait-db && uv run pytest tests/test_locations_repository.py -v`
Expected: FAIL — `TypeError: LocationsRepository.__init__() got an unexpected keyword argument 'client'`

- [ ] **Step 4: Rewrite the repository**

Replace the entire contents of `backend/src/dual_weather/repositories/locations.py`:

```python
"""Firestore access for the Location and UserProfile entities.

Documents live at `users/{sub}` (profile) and `users/{sub}/locations/{id}`.
The subcollection path supplies the per-user scoping that DynamoDB encoded in
`pk = USER#<sub>`, so no ownership filter is needed on reads — the path itself
is the authorization boundary.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from dual_weather.schemas.location import LocationOut
from dual_weather.schemas.user import UserProfile


def _now_iso() -> str:
    return datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def _doc_to_location(doc) -> LocationOut:
    data = doc.to_dict()
    return LocationOut(
        id=doc.id,
        city=data["city"],
        state=data["state"],
        latitude=float(data["latitude"]),
        longitude=float(data["longitude"]),
        created_at=data["created_at"],
    )


class LocationsRepository:
    def __init__(self, client) -> None:
        self._client = client

    def _user_doc(self, user_sub: str):
        # Auth0 subs ("auth0|abc", "apple|001") are valid Firestore document IDs:
        # only "/" is forbidden, and subs never contain one.
        return self._client.collection("users").document(user_sub)

    def _locations(self, user_sub: str):
        return self._user_doc(user_sub).collection("locations")

    def get_or_create_profile(self, *, user_sub: str, email: str | None = None) -> UserProfile:
        ref = self._user_doc(user_sub)
        snapshot = ref.get()
        if snapshot.exists:
            data = snapshot.to_dict()
            return UserProfile(
                sub=user_sub,
                created_at=data["created_at"],
                email=data.get("email"),
                display_name=data.get("display_name"),
            )

        created_at = _now_iso()
        data: dict[str, str] = {"created_at": created_at}
        if email:
            data["email"] = email
        ref.set(data)
        return UserProfile(sub=user_sub, created_at=created_at, email=email)

    def create(
        self,
        *,
        user_sub: str,
        city: str,
        state: str,
        latitude: float,
        longitude: float,
    ) -> LocationOut:
        location_id = str(uuid.uuid4())
        created_at = _now_iso()
        self._locations(user_sub).document(location_id).set(
            {
                "city": city,
                "state": state,
                "latitude": latitude,  # Firestore stores doubles natively
                "longitude": longitude,
                "created_at": created_at,
            }
        )
        return LocationOut(
            id=location_id,
            city=city,
            state=state,
            latitude=latitude,
            longitude=longitude,
            created_at=created_at,
        )

    def list(self, *, user_sub: str) -> list[LocationOut]:
        docs = self._locations(user_sub).order_by("created_at").stream()
        return [_doc_to_location(doc) for doc in docs]

    def delete(self, *, user_sub: str, location_id: str) -> None:
        # Firestore's delete() is idempotent and succeeds on a missing document,
        # which would silently downgrade the router's 404 to a 204. Read first.
        ref = self._locations(user_sub).document(location_id)
        if not ref.get().exists:
            raise KeyError(location_id)
        ref.delete()
```

- [ ] **Step 5: Rewire `deps.py`**

Replace the entire contents of `backend/src/dual_weather/deps.py`:

```python
"""Shared FastAPI dependencies for repositories and other shared state."""

from __future__ import annotations

from fastapi import Depends

from dual_weather.firestore import get_client
from dual_weather.repositories.locations import LocationsRepository
from dual_weather.settings import Settings, get_settings


def get_locations_repository(
    settings: Settings = Depends(get_settings),
) -> LocationsRepository:
    return LocationsRepository(client=get_client(settings))
```

- [ ] **Step 6: Run the repository tests**

Run: `cd backend && uv run pytest tests/test_locations_repository.py -v`
Expected: 9 passed (6 original + 3 new)

- [ ] **Step 7: Update the API tests' fixture wiring**

In `backend/tests/test_locations_api.py`, replace the helper and every test signature that names `moto_dynamo`:

```python
def _setup(firestore_db) -> tuple[TestClient, LocationsRepository]:
    repo = LocationsRepository(client=firestore_db)
```

Then rename the fixture parameter in all six test functions — `test_create_location`, `test_list_returns_only_users_own_locations`, `test_delete_location`, `test_delete_nonexistent_returns_404`, `test_create_validates_latitude`, `test_locations_requires_auth` — changing each `def test_x(moto_dynamo):` to `def test_x(firestore_db):` and each `_setup(moto_dynamo)` call to `_setup(firestore_db)`. Assertions stay untouched.

Verify none were missed:
```bash
cd backend && grep -c "firestore_db" tests/test_locations_api.py
```
Expected: `13` (one `_setup` definition + six signatures + six `_setup(...)` calls).

In `backend/tests/test_me_api.py`, make the same substitution in both tests:

```python
def test_me_creates_profile_on_first_call(firestore_db):
    repo = LocationsRepository(client=firestore_db)
```

```python
def test_me_requires_auth(firestore_db):
    repo = LocationsRepository(client=firestore_db)
```

- [ ] **Step 8: Run the full suite and lint**

Run: `cd backend && uv run pytest -q && uv run ruff check src tests`
Expected: all tests pass. `test_dynamo.py` still passes — `dynamo.py` is untouched and Task 4 removes it.

- [ ] **Step 9: Commit**

```bash
git add backend/src/dual_weather/repositories/locations.py backend/src/dual_weather/deps.py backend/tests/
git commit -m "feat!: persist locations and profiles in Firestore subcollections"
```

---

### Task 4: Remove DynamoDB

Deletes the dead code and dependencies now that nothing consumes them, and records the deploy block.

**Files:**
- Delete: `backend/src/dual_weather/dynamo.py`, `backend/scripts/init_local_dynamo.py`, `backend/tests/test_dynamo.py`
- Modify: `backend/src/dual_weather/settings.py` (drop `table_name`, `dynamo_endpoint_url`)
- Modify: `backend/tests/test_settings.py`, `backend/tests/conftest.py`
- Modify: `backend/pyproject.toml` (drop `boto3`, `moto`)
- Modify: `backend/Makefile` (drop `init-db`, guard `deploy`)
- Modify: `backend/README.md`

**Interfaces:**
- Consumes: everything from Tasks 1–3
- Produces: a backend with no AWS data-layer code. `Settings` no longer exposes `table_name` or `dynamo_endpoint_url`.

- [ ] **Step 1: Update the settings tests first**

In `backend/tests/test_settings.py`, delete `test_settings_dynamo_endpoint_local_uses_dynamodb_local` and `test_settings_dynamo_endpoint_prod_is_none` entirely (the `firestore_emulator_host` equivalents already exist in `test_firestore.py` from Task 2). Then update the first test — drop the `DW_TABLE_NAME` monkeypatch and its assertion, add `gcp_project`:

```python
def test_settings_reads_env_vars(monkeypatch):
    monkeypatch.setenv("DW_ENV", "prod")
    monkeypatch.setenv("DW_GCP_PROJECT", "dual-weather-prod")
    monkeypatch.setenv("DW_AUTH0_DOMAIN", "tenant.auth0.com")
    monkeypatch.setenv("DW_AUTH0_AUDIENCE", "https://api.dualweather/")

    s = Settings()

    assert s.env == "prod"
    assert s.gcp_project == "dual-weather-prod"
    assert s.auth0_domain == "tenant.auth0.com"
    assert s.auth0_audience == "https://api.dualweather/"
    assert s.is_local is False
```

Leave `test_settings_is_local_true_when_env_is_local` untouched — `is_local` survives because `auth.py:29` uses it for the `X-Dev-User-Sub` dev-auth bypass.

- [ ] **Step 2: Run the settings tests**

Run: `cd backend && uv run pytest tests/test_settings.py -v`
Expected: PASS — `gcp_project` already exists from Task 2, so these tests go green immediately. This is a deletion task rather than a feature task, so there is no red phase here; the step confirms the rewritten assertions are correct *before* removing the production code they used to cover.

- [ ] **Step 3: Strip DynamoDB from settings**

In `backend/src/dual_weather/settings.py`, delete the `table_name` field and the entire `dynamo_endpoint_url` property. The result:

```python
    env: Literal["local", "prod"] = "prod"
    gcp_project: str = "dual-weather-local"
    log_level: str = "INFO"

    auth0_domain: str = ""
    auth0_audience: str = ""

    @property
    def is_local(self) -> bool:
        return self.env == "local"

    @property
    def firestore_emulator_host(self) -> str | None:
        return "localhost:8002" if self.is_local else None

    @property
    def auth0_issuer(self) -> str:
        return f"https://{self.auth0_domain}/"
```

- [ ] **Step 4: Delete the DynamoDB modules**

```bash
cd backend && rm src/dual_weather/dynamo.py scripts/init_local_dynamo.py tests/test_dynamo.py
```

- [ ] **Step 5: Clean up conftest**

In `backend/tests/conftest.py`, remove the `boto3` and `moto` imports, the entire `moto_dynamo` fixture, and the entire `settings` fixture (it is unused and its docstring refers to DynamoDB Local). Strip the AWS and table env vars from `_default_env`. The file becomes:

```python
import uuid

import pytest

from dual_weather.firestore import build_client
from dual_weather.settings import get_settings


@pytest.fixture(autouse=True)
def _default_env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DW_ENV", "local")
    monkeypatch.setenv("DW_AUTH0_DOMAIN", "test.auth0.com")
    monkeypatch.setenv("DW_AUTH0_AUDIENCE", "https://api.dualweather/")
    get_settings.cache_clear()


@pytest.fixture
def firestore_db():
    """A Firestore client bound to a project ID unique to this test.

    The emulator partitions data by project, so a fresh project ID gives complete
    isolation with no inter-test cleanup — cheaper and less error-prone than
    deleting collections between tests.
    """
    project = f"test-{uuid.uuid4().hex[:12]}"
    client = build_client(project, "localhost:8002")
    yield client
    client.close()
```

- [ ] **Step 6: Drop the AWS dependencies**

In `backend/pyproject.toml`, remove `"boto3>=1.35.0,<2",` from `dependencies` and `"moto[dynamodb]>=5.0.0,<6",` from the `dev` group. Keep `mangum` — the ASGI adapter is orthogonal to storage and stays useful under Cloud Run. Keep `aws-lambda-powertools` — its removal belongs with the compute migration.

Then run: `cd backend && uv sync`

- [ ] **Step 7: Update the Makefile**

Remove the `init-db` target entirely (Firestore creates collections implicitly on first write — there is no schema step) and drop it from `.PHONY` and from `dev`'s prerequisites. Wire `wait-db` into both `dev` and `test`, and guard `deploy`:

```make
.PHONY: dev test lint format up down wait-db smoke package deploy smoke-prod

dev: up wait-db
	DW_ENV=local PYTHONPATH=src $(UVICORN) dual_weather.main:app --reload --host 0.0.0.0 --port 8000

test: up wait-db
	uv run pytest -v
```

```make
deploy: package
	@echo "ERROR: Deploys are blocked until the GCP cutover (see"
	@echo "docs/superpowers/specs/2026-07-21-firestore-local-migration-design.md §7)."
	@echo "This code has no reachable database in prod. Remove this guard when"
	@echo "real Firestore is provisioned."
	@exit 1
	./scripts/deploy.sh
```

- [ ] **Step 8: Update the README**

In `backend/README.md`, replace any DynamoDB / `make init-db` / port 8001 references with the Firestore equivalents. Add this note under the local-setup section:

```markdown
Local development runs against the **Firestore emulator** (Docker, port 8002).
`make dev` and `make test` start it and wait for readiness automatically. No GCP
account or credentials are required — `FIRESTORE_EMULATOR_HOST` makes the client
bypass auth entirely.

The emulator image is large, so the first `make up` involves a slow one-time pull.

> **Deploys are blocked.** Production Firestore is not provisioned yet, so
> `make deploy` intentionally fails. The already-deployed Lambda is unaffected.
> See `docs/superpowers/specs/2026-07-21-firestore-local-migration-design.md` §7.
```

- [ ] **Step 9: Verify no DynamoDB references remain**

Run:
```bash
cd backend && grep -rniE "dynamo|boto3|moto\b" src tests scripts Makefile compose.yaml pyproject.toml README.md | grep -v "__pycache__"
```
Expected: no output.

- [ ] **Step 10: Run the full suite from cold**

Run:
```bash
cd backend && make down && make test && uv run ruff check src tests
```
Expected: Compose starts the emulator, readiness poll succeeds, all tests pass, no lint errors.

- [ ] **Step 11: Commit**

```bash
git add -A backend/
git commit -m "refactor!: remove DynamoDB from the backend

Deploys are blocked until the GCP cutover; make deploy now fails loudly."
```

---

## Manual verification

After Task 4, confirm the running service behaves identically to the DynamoDB version:

```bash
cd backend && make dev   # in one terminal
make smoke               # in another
```

Expected: `/health` returns healthy; `POST /locations` returns 201 with `"latitude": 30.27` as a **JSON number, not a string**; `GET /locations` lists it. The float-not-string detail is the visible proof the encoding change landed correctly.

Also verify the 404 path, which is the hazard most likely to regress silently:

```bash
curl -s -o /dev/null -w '%{http_code}\n' -X DELETE \
  http://localhost:8000/locations/does-not-exist -H 'X-Dev-User-Sub: smoke-test'
```
Expected: `404` (not `204`).

## Out of scope — the GCP cutover ticket

- Provision a real Firestore database and GCP project via Terraform
- Point prod at real Firestore and remove the `get_client` guard
- Migrate compute from Lambda + API Gateway to Cloud Run or Cloud Functions
- Tear down `infra/runtime`'s DynamoDB table, IAM policy, and `DW_TABLE_NAME`
- Reconsider `aws-lambda-powertools`
- Optionally close the `get_or_create_profile` read-then-write race with a transaction
