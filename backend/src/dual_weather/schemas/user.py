from pydantic import BaseModel


class UserProfile(BaseModel):
    """Stable user identity record, lazily created on first call to /me."""

    sub: str
    created_at: str
    email: str | None = None
    display_name: str | None = None
