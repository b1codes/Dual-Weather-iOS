import os
import uuid

import pytest

from dual_weather.firestore import build_client
from dual_weather.settings import get_settings


@pytest.fixture(autouse=True)
def _restore_firestore_emulator_host():
    """Snapshot/restore FIRESTORE_EMULATOR_HOST around every test.

    dual_weather.firestore.build_client() writes this var directly into
    os.environ (google-cloud-firestore reads it from the process environment
    and offers no per-client override, so the mutation is unavoidable and
    intentionally left in place). monkeypatch.setenv/delenv only reverts
    changes made through monkeypatch itself, so a raw os.environ write like
    this one would otherwise leak into every later test in the process. This
    fixture restores the prior value (including "absent" if it was unset)
    regardless of which test set it.
    """
    sentinel = object()
    prior = os.environ.get("FIRESTORE_EMULATOR_HOST", sentinel)
    yield
    if prior is sentinel:
        os.environ.pop("FIRESTORE_EMULATOR_HOST", None)
    else:
        os.environ["FIRESTORE_EMULATOR_HOST"] = prior


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
