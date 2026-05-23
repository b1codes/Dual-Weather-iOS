from fastapi.testclient import TestClient

from dual_weather.main import app


def test_health_returns_200_and_status_ok():
    client = TestClient(app)
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
