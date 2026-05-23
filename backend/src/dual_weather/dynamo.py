"""DynamoDB resource factory.

The only place in the codebase that constructs a boto3 client/resource for DynamoDB.
Tests mock at this layer via moto.
"""

from __future__ import annotations

from functools import lru_cache
from typing import TYPE_CHECKING

import boto3

if TYPE_CHECKING:
    from dual_weather.settings import Settings


@lru_cache(maxsize=1)
def _get_resource(endpoint_url: str | None) -> boto3.resources.base.ServiceResource:
    kwargs: dict[str, str | None] = {"region_name": "us-east-2"}
    if endpoint_url is not None:
        kwargs["endpoint_url"] = endpoint_url
        kwargs["aws_access_key_id"] = "local"
        kwargs["aws_secret_access_key"] = "local"  # noqa: S105
    return boto3.resource("dynamodb", **{k: v for k, v in kwargs.items() if v is not None})


def get_table(settings: Settings):
    """Return the boto3 Table resource for the configured table name."""
    resource = _get_resource(settings.dynamo_endpoint_url)
    return resource.Table(settings.table_name)
