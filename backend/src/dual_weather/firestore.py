"""Firestore client factory.

The only place in the codebase that constructs a Firestore client. Local runs
and the test suite talk to the Firestore emulator; setting FIRESTORE_EMULATOR_HOST
makes google-cloud-firestore skip credential discovery entirely, which is why no
GCP account or service-account key is needed anywhere in this codebase yet.
"""

from __future__ import annotations

import os
from functools import lru_cache
from typing import TYPE_CHECKING

from google.auth.credentials import AnonymousCredentials
from google.cloud import firestore

if TYPE_CHECKING:
    from dual_weather.settings import Settings

_UNCONFIGURED_PROJECT = "dual-weather-local"


def build_client(project: str, emulator_host: str | None) -> firestore.Client:
    """Construct a client. With an emulator host, auth is bypassed entirely."""
    if emulator_host is not None:
        os.environ["FIRESTORE_EMULATOR_HOST"] = emulator_host
        return firestore.Client(project=project, credentials=AnonymousCredentials())
    return firestore.Client(project=project)


@lru_cache(maxsize=1)
def _cached_client(project: str, emulator_host: str | None) -> firestore.Client:
    return build_client(project, emulator_host)


def get_client(settings: Settings) -> firestore.Client:
    """Return the shared Firestore client for the configured project."""
    if not settings.is_local and settings.gcp_project == _UNCONFIGURED_PROJECT:
        raise RuntimeError(
            "DW_GCP_PROJECT is still the local default in a non-local environment. "
            "Production Firestore is not provisioned yet — this is expected until "
            "the GCP cutover ticket lands. Do not deploy."
        )
    return _cached_client(settings.gcp_project, settings.firestore_emulator_host)
