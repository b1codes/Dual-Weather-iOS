from fastapi import APIRouter, Depends

from dual_weather.auth import current_user
from dual_weather.deps import get_locations_repository
from dual_weather.repositories.locations import LocationsRepository
from dual_weather.schemas.user import UserProfile

router = APIRouter(tags=["me"])


@router.get("/me", response_model=UserProfile)
def get_me(
    user: UserProfile = current_user,
    repo: LocationsRepository = Depends(get_locations_repository),
) -> UserProfile:
    return repo.get_or_create_profile(user_sub=user.sub)
