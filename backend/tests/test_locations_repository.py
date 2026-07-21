import pytest

from dual_weather.repositories.locations import LocationsRepository


@pytest.fixture
def repo(firestore_db):
    return LocationsRepository(client=firestore_db)


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


def test_coordinates_round_trip_as_floats(repo):
    created = repo.create(
        user_sub="u",
        city="Austin",
        state="TX",
        latitude=30.266666,
        longitude=-97.733330,
    )

    listed = repo.list(user_sub="u")[0]

    assert isinstance(listed.latitude, float)
    assert isinstance(listed.longitude, float)
    assert listed.latitude == pytest.approx(30.266666)
    assert listed.longitude == pytest.approx(-97.733330)
    assert created.longitude == listed.longitude


def test_profile_is_created_once_and_reread(repo):
    first = repo.get_or_create_profile(user_sub="apple|p", email="a@b.com")
    second = repo.get_or_create_profile(user_sub="apple|p")

    assert first.created_at == second.created_at
    assert second.email == "a@b.com"


def test_list_is_empty_for_user_with_profile_but_no_locations(repo):
    repo.get_or_create_profile(user_sub="apple|lonely")

    assert repo.list(user_sub="apple|lonely") == []


def test_locations_survive_first_profile_write_after_phantom_parent(repo):
    # In Firestore, writing users/{sub}/locations/{id} does NOT create a real
    # users/{sub} document -- the parent is a "phantom" until something writes
    # it directly. get_or_create_profile's first-ever write for a user (ref.set)
    # is that direct write. If it were ever changed to overwrite the whole
    # document tree instead of just the parent's own fields (e.g. by deleting
    # and recreating the doc, or writing via a merge=False path that Firestore
    # implemented as a subtree replace), this location -- created before the
    # profile existed -- would vanish from list(). set() on a document reference
    # only touches that document's fields, not its subcollections, so it should
    # survive.
    created = repo.create(
        user_sub="apple|phantom",
        city="Austin",
        state="TX",
        latitude=30.27,
        longitude=-97.74,
    )

    repo.get_or_create_profile(user_sub="apple|phantom", email="phantom@example.com")

    listed = repo.list(user_sub="apple|phantom")
    assert len(listed) == 1
    assert listed[0].id == created.id
    assert listed[0].city == "Austin"
    assert listed[0].state == "TX"
    assert listed[0].latitude == pytest.approx(30.27)
    assert listed[0].longitude == pytest.approx(-97.74)
