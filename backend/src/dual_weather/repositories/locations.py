"""Firestore access for the Location and UserProfile entities.

Documents live at `users/{sub}` (profile) and `users/{sub}/locations/{id}`.
The subcollection path supplies the per-user scoping that DynamoDB encoded in
`pk = USER#<sub>`, so no ownership filter is needed on reads — the path itself
is the authorization boundary.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from dual_weather.schemas.location import LocationOut
from dual_weather.schemas.user import UserProfile


def _now_iso() -> str:
    return datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def _doc_to_location(doc) -> LocationOut:
    data = doc.to_dict()
    return LocationOut(
        id=doc.id,
        city=data["city"],
        state=data["state"],
        latitude=float(data["latitude"]),
        longitude=float(data["longitude"]),
        created_at=data["created_at"],
    )


class LocationsRepository:
    def __init__(self, client) -> None:
        self._client = client

    def _user_doc(self, user_sub: str):
        # Auth0 subs ("auth0|abc", "apple|001") are valid Firestore document IDs:
        # only "/" is forbidden, and subs never contain one.
        return self._client.collection("users").document(user_sub)

    def _locations(self, user_sub: str):
        return self._user_doc(user_sub).collection("locations")

    def get_or_create_profile(self, *, user_sub: str, email: str | None = None) -> UserProfile:
        ref = self._user_doc(user_sub)
        snapshot = ref.get()
        if snapshot.exists:
            data = snapshot.to_dict()
            return UserProfile(
                sub=user_sub,
                created_at=data["created_at"],
                email=data.get("email"),
                display_name=data.get("display_name"),
            )

        created_at = _now_iso()
        data: dict[str, str] = {"created_at": created_at}
        if email:
            data["email"] = email
        ref.set(data)
        return UserProfile(sub=user_sub, created_at=created_at, email=email)

    def create(
        self,
        *,
        user_sub: str,
        city: str,
        state: str,
        latitude: float,
        longitude: float,
    ) -> LocationOut:
        location_id = str(uuid.uuid4())
        created_at = _now_iso()
        self._locations(user_sub).document(location_id).set(
            {
                "city": city,
                "state": state,
                "latitude": latitude,  # Firestore stores doubles natively
                "longitude": longitude,
                "created_at": created_at,
            }
        )
        return LocationOut(
            id=location_id,
            city=city,
            state=state,
            latitude=latitude,
            longitude=longitude,
            created_at=created_at,
        )

    def list(self, *, user_sub: str) -> list[LocationOut]:
        docs = self._locations(user_sub).order_by("created_at").stream()
        return [_doc_to_location(doc) for doc in docs]

    def delete(self, *, user_sub: str, location_id: str) -> None:
        # Firestore's delete() is idempotent and succeeds on a missing document,
        # which would silently downgrade the router's 404 to a 204. Read first.
        ref = self._locations(user_sub).document(location_id)
        if not ref.get().exists:
            raise KeyError(location_id)
        ref.delete()
