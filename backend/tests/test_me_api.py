from fastapi.testclient import TestClient

from dual_weather.deps import get_locations_repository
from dual_weather.main import app
from dual_weather.repositories.locations import LocationsRepository


def test_me_creates_profile_on_first_call(firestore_db):
    repo = LocationsRepository(client=firestore_db)
    app.dependency_overrides[get_locations_repository] = lambda: repo
    try:
        client = TestClient(app)

        response = client.get("/me", headers={"X-Dev-User-Sub": "apple|new-user"})

        assert response.status_code == 200
        body = response.json()
        assert body["sub"] == "apple|new-user"
        assert body["created_at"]  # set on insert

        # Second call returns the same created_at (didn't re-create)
        second = client.get("/me", headers={"X-Dev-User-Sub": "apple|new-user"})
        assert second.status_code == 200
        assert second.json()["created_at"] == body["created_at"]
    finally:
        app.dependency_overrides.clear()


def test_me_requires_auth(firestore_db):
    repo = LocationsRepository(client=firestore_db)
    app.dependency_overrides[get_locations_repository] = lambda: repo
    try:
        client = TestClient(app)
        response = client.get("/me")
        assert response.status_code == 401
    finally:
        app.dependency_overrides.clear()
