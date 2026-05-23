import os
import pytest


@pytest.fixture(autouse=True)
def _default_env(monkeypatch: pytest.MonkeyPatch) -> None:
    """Set safe defaults so settings doesn't try to reach real AWS during tests."""
    monkeypatch.setenv("DW_ENV", "local")
    monkeypatch.setenv("DW_TABLE_NAME", "DualWeatherTest")
    monkeypatch.setenv("DW_AUTH0_DOMAIN", "test.auth0.com")
    monkeypatch.setenv("DW_AUTH0_AUDIENCE", "https://api.dualweather/")
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")
    monkeypatch.setenv("AWS_DEFAULT_REGION", "us-east-2")
