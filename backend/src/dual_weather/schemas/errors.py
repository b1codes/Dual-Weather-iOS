from pydantic import BaseModel


class Problem(BaseModel):
    """RFC 7807 Problem Details for HTTP APIs.

    https://datatracker.ietf.org/doc/html/rfc7807
    """

    type: str
    title: str
    status: int
    detail: str
