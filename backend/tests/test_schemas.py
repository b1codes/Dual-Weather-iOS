import pytest
from pydantic import ValidationError

from dual_weather.schemas.errors import Problem
from dual_weather.schemas.location import LocationIn, LocationOut
from dual_weather.schemas.user import UserProfile


def test_location_in_accepts_valid_payload():
    loc = LocationIn(city="Austin", state="TX", latitude=30.27, longitude=-97.74)
    assert loc.city == "Austin"
    assert loc.state == "TX"
    assert loc.latitude == 30.27
    assert loc.longitude == -97.74


def test_location_in_rejects_blank_city():
    with pytest.raises(ValidationError):
        LocationIn(city="", state="TX", latitude=0.0, longitude=0.0)


def test_location_in_rejects_invalid_latitude():
    with pytest.raises(ValidationError):
        LocationIn(city="X", state="TX", latitude=91.0, longitude=0.0)


def test_location_in_rejects_invalid_longitude():
    with pytest.raises(ValidationError):
        LocationIn(city="X", state="TX", latitude=0.0, longitude=181.0)


def test_location_out_serializes_with_id_and_created_at():
    loc = LocationOut(
        id="01HXYZ",
        city="Austin",
        state="TX",
        latitude=30.27,
        longitude=-97.74,
        created_at="2026-05-23T12:00:00Z",
    )
    dumped = loc.model_dump()
    assert dumped["id"] == "01HXYZ"
    assert dumped["created_at"] == "2026-05-23T12:00:00Z"


def test_user_profile_minimum_fields():
    user = UserProfile(sub="apple|123", created_at="2026-05-23T12:00:00Z")
    assert user.sub == "apple|123"
    assert user.email is None


def test_problem_serializes_rfc7807_keys():
    p = Problem(
        type="https://dualweather.app/errors/not-found",
        title="Not found",
        status=404,
        detail="No such location",
    )
    dumped = p.model_dump()
    assert set(dumped.keys()) == {"type", "title", "status", "detail"}
    assert dumped["status"] == 404
