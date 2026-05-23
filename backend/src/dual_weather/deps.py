"""Shared FastAPI dependencies for repositories and other shared state."""

from __future__ import annotations

from fastapi import Depends

from dual_weather.dynamo import get_table
from dual_weather.repositories.locations import LocationsRepository
from dual_weather.settings import Settings, get_settings


def get_locations_repository(
    settings: Settings = Depends(get_settings),
) -> LocationsRepository:
    return LocationsRepository(table=get_table(settings))
