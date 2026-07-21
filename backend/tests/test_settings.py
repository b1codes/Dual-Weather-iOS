from dual_weather.settings import Settings


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


def test_settings_is_local_true_when_env_is_local(monkeypatch):
    monkeypatch.setenv("DW_ENV", "local")
    s = Settings()
    assert s.is_local is True
