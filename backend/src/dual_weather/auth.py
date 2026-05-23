"""Resolve the current user from request context.

In `prod`, claims come from API Gateway's JWT authorizer via the Mangum-exposed
`aws.event` dict in the ASGI scope. In `local`, the `X-Dev-User-Sub` header is
accepted as a shortcut. The dev-header branch is unreachable in `prod`.
"""

from __future__ import annotations

from typing import Any

from fastapi import Depends, HTTPException, Request, status

from dual_weather.schemas.user import UserProfile
from dual_weather.settings import Settings, get_settings


def _extract_jwt_sub(request: Request) -> str | None:
    aws_event: dict[str, Any] | None = request.scope.get("aws.event")
    if not aws_event:
        return None
    try:
        return aws_event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"]
    except (KeyError, TypeError):
        return None


def _resolve_user(request: Request, settings: Settings) -> UserProfile:
    if settings.is_local:
        sub = request.headers.get("X-Dev-User-Sub")
        if sub:
            return UserProfile(sub=sub, created_at="")

    sub = _extract_jwt_sub(request)
    if sub:
        return UserProfile(sub=sub, created_at="")

    raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Unauthenticated")


def _current_user(
    request: Request, settings: Settings = Depends(get_settings)
) -> UserProfile:
    return _resolve_user(request, settings)


current_user = Depends(_current_user)
