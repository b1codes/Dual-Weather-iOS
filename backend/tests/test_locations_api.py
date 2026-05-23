from fastapi.testclient import TestClient

from dual_weather.deps import get_locations_repository
from dual_weather.main import app
from dual_weather.repositories.locations import LocationsRepository


def _setup(moto_dynamo) -> tuple[TestClient, LocationsRepository]:
    repo = LocationsRepository(table=moto_dynamo)
    app.dependency_overrides[get_locations_repository] = lambda: repo
    return TestClient(app), repo


def test_create_location(moto_dynamo):
    client, _ = _setup(moto_dynamo)
    try:
        response = client.post(
            "/locations",
            headers={"X-Dev-User-Sub": "u1"},
            json={"city": "Austin", "state": "TX", "latitude": 30.27, "longitude": -97.74},
        )
        assert response.status_code == 201
        body = response.json()
        assert body["id"]
        assert body["city"] == "Austin"
        assert body["created_at"]
    finally:
        app.dependency_overrides.clear()


def test_list_returns_only_users_own_locations(moto_dynamo):
    client, _ = _setup(moto_dynamo)
    try:
        client.post(
            "/locations",
            headers={"X-Dev-User-Sub": "u1"},
            json={"city": "Austin", "state": "TX", "latitude": 30.0, "longitude": -97.0},
        )
        client.post(
            "/locations",
            headers={"X-Dev-User-Sub": "u2"},
            json={"city": "Reno", "state": "NV", "latitude": 39.0, "longitude": -119.0},
        )

        u1_locations = client.get("/locations", headers={"X-Dev-User-Sub": "u1"}).json()
        u2_locations = client.get("/locations", headers={"X-Dev-User-Sub": "u2"}).json()

        assert len(u1_locations) == 1
        assert u1_locations[0]["city"] == "Austin"
        assert len(u2_locations) == 1
        assert u2_locations[0]["city"] == "Reno"
    finally:
        app.dependency_overrides.clear()


def test_delete_location(moto_dynamo):
    client, _ = _setup(moto_dynamo)
    try:
        created = client.post(
            "/locations",
            headers={"X-Dev-User-Sub": "u1"},
            json={"city": "X", "state": "Y", "latitude": 0.0, "longitude": 0.0},
        ).json()

        response = client.delete(
            f"/locations/{created['id']}", headers={"X-Dev-User-Sub": "u1"}
        )
        assert response.status_code == 204

        listed = client.get("/locations", headers={"X-Dev-User-Sub": "u1"}).json()
        assert listed == []
    finally:
        app.dependency_overrides.clear()


def test_delete_nonexistent_returns_404(moto_dynamo):
    client, _ = _setup(moto_dynamo)
    try:
        response = client.delete(
            "/locations/does-not-exist", headers={"X-Dev-User-Sub": "u1"}
        )
        assert response.status_code == 404
        body = response.json()
        assert body["type"].startswith("https://dualweather.app/errors/")
        assert body["status"] == 404
    finally:
        app.dependency_overrides.clear()


def test_create_validates_latitude(moto_dynamo):
    client, _ = _setup(moto_dynamo)
    try:
        response = client.post(
            "/locations",
            headers={"X-Dev-User-Sub": "u1"},
            json={"city": "X", "state": "Y", "latitude": 999.0, "longitude": 0.0},
        )
        assert response.status_code == 422
    finally:
        app.dependency_overrides.clear()


def test_locations_requires_auth(moto_dynamo):
    client, _ = _setup(moto_dynamo)
    try:
        response = client.get("/locations")
        assert response.status_code == 401
    finally:
        app.dependency_overrides.clear()
