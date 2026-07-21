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


def test_get_client_rejects_prod_with_non_default_project(monkeypatch):
    """The guard must fire for ANY non-local env, not just the default sentinel.

    A staging/typo project id (anything other than the local default) must
    still be rejected in a non-local environment, since production Firestore
    is not provisioned for any project yet.
    """
    monkeypatch.setenv("DW_ENV", "prod")
    monkeypatch.setenv("DW_GCP_PROJECT", "some-staging-project-typo")

    with pytest.raises(RuntimeError, match="GCP cutover"):
        get_client(Settings())


def test_settings_emulator_host_local(monkeypatch):
    monkeypatch.setenv("DW_ENV", "local")
    assert Settings().firestore_emulator_host == "localhost:8002"


def test_settings_emulator_host_prod_is_none(monkeypatch):
    monkeypatch.setenv("DW_ENV", "prod")
    assert Settings().firestore_emulator_host is None
