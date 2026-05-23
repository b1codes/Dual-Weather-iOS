from fastapi import APIRouter, Depends, HTTPException, Response, status

from dual_weather.auth import current_user
from dual_weather.deps import get_locations_repository
from dual_weather.repositories.locations import LocationsRepository
from dual_weather.schemas.location import LocationIn, LocationOut
from dual_weather.schemas.user import UserProfile

router = APIRouter(prefix="/locations", tags=["locations"])


@router.get("", response_model=list[LocationOut])
def list_locations(
    user: UserProfile = current_user,
    repo: LocationsRepository = Depends(get_locations_repository),
) -> list[LocationOut]:
    return repo.list(user_sub=user.sub)


@router.post("", response_model=LocationOut, status_code=status.HTTP_201_CREATED)
def create_location(
    payload: LocationIn,
    user: UserProfile = current_user,
    repo: LocationsRepository = Depends(get_locations_repository),
) -> LocationOut:
    return repo.create(
        user_sub=user.sub,
        city=payload.city,
        state=payload.state,
        latitude=payload.latitude,
        longitude=payload.longitude,
    )


@router.delete("/{location_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_location(
    location_id: str,
    user: UserProfile = current_user,
    repo: LocationsRepository = Depends(get_locations_repository),
) -> Response:
    try:
        repo.delete(user_sub=user.sub, location_id=location_id)
    except KeyError as exc:
        raise HTTPException(
            status_code=404,
            detail=f"No saved location with id {location_id!r} for this user.",
        ) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)
