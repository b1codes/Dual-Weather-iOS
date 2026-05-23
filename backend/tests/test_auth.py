import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

from dual_weather.auth import current_user
from dual_weather.schemas.user import UserProfile


@pytest.fixture
def app_with_protected_route():
    app = FastAPI()

    @app.get("/whoami")
    def whoami(user: UserProfile = current_user) -> dict[str, str]:
        return {"sub": user.sub}

    return app


def test_local_env_accepts_dev_header(app_with_protected_route, monkeypatch):
    monkeypatch.setenv("DW_ENV", "local")
    client = TestClient(app_with_protected_route)

    response = client.get("/whoami", headers={"X-Dev-User-Sub": "apple|test123"})

    assert response.status_code == 200
    assert response.json() == {"sub": "apple|test123"}


def test_local_env_rejects_request_without_dev_header(app_with_protected_route, monkeypatch):
    monkeypatch.setenv("DW_ENV", "local")
    client = TestClient(app_with_protected_route)

    response = client.get("/whoami")
    assert response.status_code == 401


def test_prod_env_reads_sub_from_request_scope(app_with_protected_route, monkeypatch):
    monkeypatch.setenv("DW_ENV", "prod")

    # API Gateway's claims context is attached to the ASGI scope by Mangum.
    # We simulate that via a middleware injected before client construction.
    @app_with_protected_route.middleware("http")
    async def inject_claims(request, call_next):
        request.scope["aws.event"] = {
            "requestContext": {"authorizer": {"jwt": {"claims": {"sub": "auth0|prod-sub"}}}}
        }
        return await call_next(request)

    client = TestClient(app_with_protected_route)
    response = client.get("/whoami")
    assert response.status_code == 200
    assert response.json() == {"sub": "auth0|prod-sub"}


def test_prod_env_returns_401_when_no_claims(app_with_protected_route, monkeypatch):
    monkeypatch.setenv("DW_ENV", "prod")
    client = TestClient(app_with_protected_route)

    response = client.get("/whoami")
    assert response.status_code == 401
