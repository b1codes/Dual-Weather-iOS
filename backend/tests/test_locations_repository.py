import pytest

from dual_weather.repositories.locations import LocationsRepository


@pytest.fixture
def repo(moto_dynamo):
    return LocationsRepository(table=moto_dynamo)


def test_create_and_list_one_location(repo):
    created = repo.create(
        user_sub="apple|001",
        city="Austin",
        state="TX",
        latitude=30.27,
        longitude=-97.74,
    )

    assert created.id
    assert created.city == "Austin"

    listed = repo.list(user_sub="apple|001")
    assert len(listed) == 1
    assert listed[0].id == created.id


def test_list_returns_empty_for_user_with_no_locations(repo):
    assert repo.list(user_sub="apple|nobody") == []


def test_locations_are_scoped_per_user(repo):
    repo.create(user_sub="user|A", city="A", state="AA", latitude=1.0, longitude=1.0)
    repo.create(user_sub="user|A", city="A2", state="AA", latitude=2.0, longitude=2.0)
    repo.create(user_sub="user|B", city="B", state="BB", latitude=3.0, longitude=3.0)

    assert len(repo.list(user_sub="user|A")) == 2
    assert len(repo.list(user_sub="user|B")) == 1


def test_delete_removes_only_that_location(repo):
    loc1 = repo.create(user_sub="u", city="C1", state="S", latitude=0.0, longitude=0.0)
    loc2 = repo.create(user_sub="u", city="C2", state="S", latitude=0.0, longitude=0.0)

    repo.delete(user_sub="u", location_id=loc1.id)

    remaining = repo.list(user_sub="u")
    assert len(remaining) == 1
    assert remaining[0].id == loc2.id


def test_delete_nonexistent_location_raises(repo):
    with pytest.raises(KeyError):
        repo.delete(user_sub="u", location_id="does-not-exist")


def test_delete_cannot_cross_user_boundary(repo):
    loc = repo.create(user_sub="owner", city="X", state="Y", latitude=0.0, longitude=0.0)

    with pytest.raises(KeyError):
        repo.delete(user_sub="attacker", location_id=loc.id)

    # Owner's data still there
    assert len(repo.list(user_sub="owner")) == 1
