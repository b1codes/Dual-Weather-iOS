from pydantic import BaseModel, Field


class LocationIn(BaseModel):
    """User-supplied saved-location payload."""

    city: str = Field(min_length=1, max_length=120)
    state: str = Field(min_length=1, max_length=120)
    latitude: float = Field(ge=-90.0, le=90.0)
    longitude: float = Field(ge=-180.0, le=180.0)


class LocationOut(LocationIn):
    """Server-shaped response including server-assigned fields."""

    id: str
    created_at: str
