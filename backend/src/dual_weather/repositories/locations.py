"""DynamoDB access for the Location entity.

The only module besides `dynamo.py` that touches boto3.
"""

from __future__ import annotations

import uuid

from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError

from dual_weather.schemas.location import LocationOut
from dual_weather.schemas.user import UserProfile


def _now_iso() -> str:
    from datetime import UTC, datetime

    return datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def _user_pk(user_sub: str) -> str:
    return f"USER#{user_sub}"


def _location_sk(location_id: str) -> str:
    return f"LOC#{location_id}"


def _item_to_location(item: dict) -> LocationOut:
    location_id = item["sk"].split("#", 1)[1]
    return LocationOut(
        id=location_id,
        city=item["city"],
        state=item["state"],
        latitude=float(item["latitude"]),
        longitude=float(item["longitude"]),
        created_at=item["created_at"],
    )


class LocationsRepository:
    def __init__(self, table) -> None:
        self._table = table

    def get_or_create_profile(self, *, user_sub: str, email: str | None = None) -> UserProfile:
        pk = _user_pk(user_sub)
        sk = "PROFILE"
        existing = self._table.get_item(Key={"pk": pk, "sk": sk}).get("Item")
        if existing:
            return UserProfile(
                sub=user_sub,
                created_at=existing["created_at"],
                email=existing.get("email"),
                display_name=existing.get("display_name"),
            )

        created_at = _now_iso()
        item = {"pk": pk, "sk": sk, "created_at": created_at}
        if email:
            item["email"] = email
        self._table.put_item(Item=item)
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
        item = {
            "pk": _user_pk(user_sub),
            "sk": _location_sk(location_id),
            "city": city,
            "state": state,
            "latitude": str(latitude),  # DynamoDB doesn't store native floats
            "longitude": str(longitude),
            "created_at": _now_iso(),
        }
        self._table.put_item(Item=item)
        return _item_to_location(item)

    def list(self, *, user_sub: str) -> list[LocationOut]:
        result = self._table.query(
            KeyConditionExpression=Key("pk").eq(_user_pk(user_sub)) & Key("sk").begins_with("LOC#")
        )
        return [_item_to_location(item) for item in result.get("Items", [])]

    def delete(self, *, user_sub: str, location_id: str) -> None:
        try:
            self._table.delete_item(
                Key={"pk": _user_pk(user_sub), "sk": _location_sk(location_id)},
                ConditionExpression="attribute_exists(pk)",
                ReturnValues="ALL_OLD",
            )
        except ClientError as e:
            if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
                raise KeyError(location_id) from e
            raise
