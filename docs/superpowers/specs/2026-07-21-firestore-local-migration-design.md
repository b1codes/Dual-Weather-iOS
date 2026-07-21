---
title: Firestore Local Migration Design
date: 2026-07-21
author: Brandon Lamer-Connolly
status: approved-pending-implementation-plan
ticket: https://app.clickup.com/t/86bb077qy
---

# Firestore Local Migration Design

## 1. Context

The backend currently persists to DynamoDB: a single-table design (`pk` / `sk`)
running against `amazon/dynamodb-local` in Docker for development, and a real
`aws_dynamodb_table` in production behind API Gateway + Lambda.

The project is migrating to GCP. The GCP account is not yet provisioned, so this
ticket moves **the application code** to Firestore now, running entirely against
the Firestore emulator, so that the eventual production cutover is a
configuration change rather than a rewrite.

DynamoDB is removed from the application **entirely** — this is not a
dual-backend arrangement. There is deliberately no working production
configuration at the end of this ticket; see §7.

> Historical note: the May 2026 backend extraction
> (`2026-05-23-backend-infra-extraction-design.md`) migrated this project *off*
> Firestore and onto DynamoDB. This ticket reverses that storage decision while
> keeping the API, auth, and monorepo structure that work delivered.

Goals:
- Replace all DynamoDB access with Firestore.
- Run local development and the full test suite against the Firestore emulator,
  with no GCP account, project, or credentials required.
- Leave the HTTP API contract byte-identical, so the iOS app is untouched.
- Leave `infra/` untouched, so the AWS teardown happens alongside GCP
  provisioning rather than stranding the deployed stack.

Non-goals:
- Provisioning real Firestore, or any GCP resource. Emulator only.
- Migrating data out of the DynamoDB table. It holds only dev and smoke-test
  rows; this is a clean cutover.
- Moving compute off Lambda. Cloud Run / Cloud Functions is a later decision.
- Changing auth. Auth0 remains the sole IdP.
- Any change to `frontend/`.

## 2. Decision summary

| Topic | Decision |
|---|---|
| Store | Firestore, replacing DynamoDB outright. No abstraction layer over the two. |
| Local runtime | Firestore emulator via Docker Compose, `gcr.io/google.com/cloudsdktool/google-cloud-cli:577.0.0-emulators`, host port `8002`. |
| Data model | Subcollections — `users/{sub}` for the profile, `users/{sub}/locations/{id}` for saved locations. |
| Credentials | None. `FIRESTORE_EMULATOR_HOST` makes the client skip auth entirely. |
| Tests | Full suite runs against the emulator. `make test` starts it. `moto` removed. |
| Test isolation | Unique Firestore project ID per test, rather than inter-test cleanup. |
| Infra | `infra/` unchanged. AWS teardown deferred to the GCP cutover ticket. |
| Deploys | Blocked until cutover. `make deploy` carries a guard comment. |
| Prod config | Intentionally non-functional; fails loudly. See §7. |
| Data migration | None. |

## 3. Architecture

The dependency-injection seam already in place does the heavy lifting. Routers
depend on `LocationsRepository` through FastAPI's `Depends`, and only two modules
ever touched boto3. Replacing the store is therefore contained to the factory and
the repository.

```
routers/{locations,me}.py
        │  Depends(get_locations_repository)
        ▼
deps.py
        │  LocationsRepository(client=get_client(settings))
        ▼
repositories/locations.py   ── rewritten for Firestore
        │
        ▼
firestore.py                ── new; the only module constructing a client
```

`repositories/locations.py` keeps both its filename and its `LocationsRepository`
class name. Every import across `deps.py`, both routers, and the test suite
therefore stays valid — only the internals change.

### File-level blast radius

| File | Action |
|---|---|
| `src/dual_weather/firestore.py` | **new** — cached client factory |
| `src/dual_weather/repositories/locations.py` | **rewrite** — same name, Firestore internals |
| `src/dual_weather/dynamo.py` | **delete** |
| `src/dual_weather/settings.py` | edit — swap Dynamo fields for GCP fields |
| `src/dual_weather/deps.py` | edit — inject client instead of table |
| `scripts/init_local_dynamo.py` | **delete** — Firestore is schemaless, nothing to create |
| `backend/compose.yaml` | replace the `dynamodb-local` service |
| `backend/Makefile` | `dev` / `test` / `init-db` / `deploy` targets |
| `backend/pyproject.toml` | dependency swap |
| `tests/conftest.py` | replace `moto_dynamo` with `firestore_db` |
| `tests/test_dynamo.py` | **delete** |
| `tests/test_firestore.py` | **new** — factory wiring |
| `tests/test_{locations_api,me_api,locations_repository}.py` | edit — fixture rename only |
| `tests/test_settings.py` | edit — replace Dynamo-specific assertions |
| `infra/**` | **untouched** |
| `frontend/**` | **untouched** |
| `src/dual_weather/{main,auth}.py`, `routers/**`, `schemas/**` | **untouched** |

## 4. Data model

DynamoDB's composite-key encoding is discarded. The subcollection path supplies
the per-user scoping that `pk = USER#<sub>` previously encoded, so
`_user_pk`, `_location_sk`, and `_item_to_location`'s `split("#", 1)` parsing all
disappear.

```
users/{sub}
    created_at:   "2026-07-21T00:00:00Z"
    email:        "user@example.com" | absent
    display_name: "Name" | absent

users/{sub}/locations/{uuid4}
    city:       "Austin"
    state:      "TX"
    latitude:    30.27      # native double
    longitude:  -97.74      # native double
    created_at: "2026-07-21T00:00:00Z"
```

Listing is `.collection("locations").stream()` on the user document. No composite
index is required, and no ownership filter is needed on reads — the document path
itself is the authorization boundary. `LocationOut.id` continues to be the
location UUID, now carried as the document ID.

### Behaviors that must be preserved deliberately

These are the two places Firestore's semantics differ from DynamoDB's, and both
are load-bearing for the existing API contract:

1. **Delete of a missing id must raise `KeyError`.** DynamoDB enforced this with
   `ConditionExpression="attribute_exists(pk)"`, whose
   `ConditionalCheckFailedException` the repository converted to `KeyError`, which
   `routers/locations.py` turns into a 404. Firestore's `DocumentReference.delete()`
   is idempotent and succeeds silently on a missing document, which would
   downgrade that 404 to a 204. The implementation reads the document first and
   raises `KeyError` when absent.

2. **Coordinates become native doubles.** DynamoDB has no float type, so `create`
   wrote `str(latitude)` and `_item_to_location` cast back with `float()`.
   Firestore stores doubles natively, so both conversions are removed.
   `LocationOut` still declares `float`, so the JSON delivered to the iOS app is
   unchanged — including negative longitudes and fractional precision.

`get_or_create_profile` keeps its existing read-then-write race. Firestore
transactions could close it, but that is a pre-existing behavior and out of scope
here.

## 5. Configuration

| Setting | Before | After |
|---|---|---|
| `table_name` | `"DualWeather"` | removed |
| `dynamo_endpoint_url` | `http://localhost:8001` when local | removed |
| `is_local` | — | **kept**; `auth.py` uses it for the `X-Dev-User-Sub` dev bypass |
| `gcp_project` | — | new, default `dual-weather-local` |
| `firestore_emulator_host` | — | new, `localhost:8002` when `is_local`, else `None` |

`firestore.py` exports `FIRESTORE_EMULATOR_HOST` into the process environment
before constructing the client whenever `firestore_emulator_host` is set. That
env var is the entire local/real switch: `google-cloud-firestore` reads it
directly, skips Application Default Credentials, and speaks plaintext gRPC to the
emulator. **No service account, key file, or GCP project is required for any part
of this ticket** — which is precisely what unblocks the work ahead of the GCP
account.

The factory is `@lru_cache`'d, mirroring the shape `dynamo.py` had.

### Dependencies

Added to main dependencies: `google-cloud-firestore`.
Removed: `boto3` (main), `moto[dynamodb]` (dev).
Retained: `mangum` — the ASGI adapter is orthogonal to storage and remains useful
under Cloud Run or Cloud Functions.

`aws-lambda-powertools` is retained for now; it is referenced by the Lambda
logging config and its removal belongs with the compute migration.

## 6. Local development and tests

### Compose

The `dynamodb-local` service is replaced by:

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

The tag is pinned, matching the existing convention of pinning
`amazon/dynamodb-local:2.5.2`. The image is substantially larger than
`dynamodb-local`, so the first `make up` on a machine involves a slow pull. This
is a one-time cost and is called out in the backend README.

### Makefile

- `init-db` is **removed**. Firestore creates collections implicitly on first
  write, so there is no schema step. `dev` no longer depends on it.
- `dev` depends on `up` and exports `DW_ENV=local`.
- `test` depends on `up` and waits for emulator readiness before invoking pytest,
  so a cold `make test` still succeeds as a single command. Docker is now a hard
  requirement for the test suite — an accepted trade, since `moto`'s in-process
  mock has no Firestore equivalent and the emulator is Google's supported answer.
- `deploy` gains a guard comment recording that deploys are blocked until the GCP
  cutover.

Readiness is polled against the emulator's HTTP root with a bounded timeout
rather than a fixed `sleep`, so the suite fails with a clear message instead of a
confusing connection error if the container never comes up.

### Test strategy

`conftest.py`'s `moto_dynamo` fixture is replaced by a `firestore_db` fixture
that connects to the emulator and assigns **a unique project ID per test**. The
emulator partitions data by project, so this yields complete isolation without
per-test collection cleanup — faster and less error-prone than deleting documents
between tests.

Three test files consume that fixture — `test_locations_api.py`, `test_me_api.py`,
and `test_locations_repository.py` — and each swaps only the fixture name. Their
assertions are unchanged, which is the intended signal: if the API-level tests
pass untouched, the HTTP contract survived the migration.

`test_settings.py` needs real edits rather than a rename. Two whole tests
(`test_settings_dynamo_endpoint_local_uses_dynamodb_local` and
`test_settings_dynamo_endpoint_prod_is_none`) are replaced by equivalents for
`firestore_emulator_host`, and `test_settings_reads_env_vars` drops its
`DW_TABLE_NAME` monkeypatch and `table_name` assertion in favor of `gcp_project`.
The two `is_local` tests survive untouched, since that property remains.

`conftest.py`'s autouse `_default_env` fixture also drops its three `AWS_*` env
vars and `DW_TABLE_NAME`, and its unused `settings` fixture — whose docstring
refers to DynamoDB Local — is removed.

`test_dynamo.py` is deleted and `test_firestore.py` replaces it, covering factory
wiring and emulator-host handling.

Explicit new coverage for the §4 hazards:
- deleting a nonexistent location still returns 404
- coordinates round-trip as floats, including a negative longitude and
  fractional precision
- one user cannot read or delete another user's locations

## 7. The production gap

At the end of this ticket the repository has **no working production
configuration**. With `DW_ENV=prod`, no emulator host is set and no GCP
credentials exist, so client construction cannot succeed.

This is inherent to migrating local-first and is accepted. Two mitigations:

1. **Fail loudly.** When `is_local` is false and `gcp_project` is still the
   `dual-weather-local` default, `firestore.py` raises a clear configuration
   error naming the GCP cutover as the prerequisite — rather than surfacing an
   opaque Application Default Credentials stack trace.

2. **Do not deploy.** `make deploy` must not be run until the cutover ticket. The
   already-deployed Lambda is unaffected — it runs the zip stored in AWS, not the
   working tree — but a redeploy would ship code with no reachable database.

`infra/` is left untouched for the same reason. `infra/runtime/dynamodb.tf`
carries `prevent_destroy = true`, and both `lambda.tf` (via the `DW_TABLE_NAME`
env var) and `iam.tf` (via the table access policy) reference
`aws_dynamodb_table.main`. Removing the table resource therefore cascades through
three files and would strand the deployed function. That teardown belongs in the
GCP cutover, where the replacement is provisioned in the same change.

The now-unused `DW_TABLE_NAME` env var on the deployed Lambda is harmless — the
new settings model simply ignores it, as `extra="ignore"` is already configured.

## 8. Follow-on work (not this ticket)

- Provision a real Firestore database and GCP project via Terraform.
- Point production at real Firestore; remove the §7 guard.
- Migrate compute from Lambda + API Gateway to Cloud Run or Cloud Functions.
- Tear down `infra/runtime`'s DynamoDB table, its IAM policy, and the
  `DW_TABLE_NAME` env var.
- Reconsider `aws-lambda-powertools` once compute moves.
- Optionally close the `get_or_create_profile` race with a Firestore transaction.
