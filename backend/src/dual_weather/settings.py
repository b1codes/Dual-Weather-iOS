from functools import lru_cache
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application configuration loaded from environment variables.

    Prefix every env var with DW_ to avoid colliding with AWS-provided ones.
    """

    model_config = SettingsConfigDict(
        env_prefix="DW_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    env: Literal["local", "prod"] = "prod"
    table_name: str = "DualWeather"
    gcp_project: str = "dual-weather-local"
    log_level: str = "INFO"

    auth0_domain: str = ""
    auth0_audience: str = ""

    @property
    def is_local(self) -> bool:
        return self.env == "local"

    @property
    def dynamo_endpoint_url(self) -> str | None:
        return "http://localhost:8001" if self.is_local else None

    @property
    def firestore_emulator_host(self) -> str | None:
        return "localhost:8002" if self.is_local else None

    @property
    def auth0_issuer(self) -> str:
        return f"https://{self.auth0_domain}/"


@lru_cache
def get_settings() -> Settings:
    return Settings()
