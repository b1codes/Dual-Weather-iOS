"""Firestore client factory.

The only place in the codebase that constructs a Firestore client. Local runs
and the test suite talk to the Firestore emulator; setting FIRESTORE_EMULATOR_HOST
makes google-cloud-firestore skip credential discovery entirely, which is why no
GCP account or service-account key is needed anywhere in this codebase yet.
"""

from __future__ import annotations

import os
from functools import cache
from typing import TYPE_CHECKING

from google.auth.credentials import AnonymousCredentials
from google.cloud import firestore

if TYPE_CHECKING:
    from dual_weather.settings import Settings


def build_client(project: str, emulator_host: str | None) -> firestore.Client:
    """Construct a client. With an emulator host, auth is bypassed entirely."""
    if emulator_host is not None:
        os.environ["FIRESTORE_EMULATOR_HOST"] = emulator_host
        return firestore.Client(project=project, credentials=AnonymousCredentials())
    return firestore.Client(project=project)


# functools.cache == lru_cache(maxsize=None): entries are never evicted. Each
# entry wraps a live firestore.Client (and its gRPC channel) that is never
# explicitly closed, so evicting an entry under an LRU policy would leak that
# channel. The cache key space is small and bounded (one project/emulator-host
# pair per environment), so unbounded growth is not a practical concern.
@cache
def _cached_client(project: str, emulator_host: str | None) -> firestore.Client:
    return build_client(project, emulator_host)


def get_client(settings: Settings) -> firestore.Client:
    """Return the shared Firestore client for the configured project.

    Guard: unconditionally rejects every non-local environment, regardless of
    what gcp_project is set to. Production Firestore is not provisioned for
    any project yet, so any non-local run would otherwise fall through to
    Application Default Credentials discovery and fail with an opaque stack
    trace. This entire conditional is temporary scaffolding — delete it at
    the GCP cutover once real Firestore project(s) exist.
    """
    if not settings.is_local:
        raise RuntimeError(
            "Firestore is not available outside the local environment yet. "
            "Production Firestore is not provisioned for any GCP project — this "
            "is expected until the GCP cutover ticket lands. Do not deploy."
        )
    return _cached_client(settings.gcp_project, settings.firestore_emulator_host)
