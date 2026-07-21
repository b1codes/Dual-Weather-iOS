import os

import boto3
import pytest
from moto import mock_aws

from dual_weather.settings import Settings, get_settings


@pytest.fixture(autouse=True)
def _restore_firestore_emulator_host():
    """Snapshot/restore FIRESTORE_EMULATOR_HOST around every test.

    dual_weather.firestore.build_client() writes this var directly into
    os.environ (google-cloud-firestore reads it from the process environment
    and offers no per-client override, so the mutation is unavoidable and
    intentionally left in place). monkeypatch.setenv/delenv only reverts
    changes made through monkeypatch itself, so a raw os.environ write like
    this one would otherwise leak into every later test in the process. This
    fixture restores the prior value (including "absent" if it was unset)
    regardless of which test set it.
    """
    sentinel = object()
    prior = os.environ.get("FIRESTORE_EMULATOR_HOST", sentinel)
    yield
    if prior is sentinel:
        os.environ.pop("FIRESTORE_EMULATOR_HOST", None)
    else:
        os.environ["FIRESTORE_EMULATOR_HOST"] = prior


@pytest.fixture(autouse=True)
def _default_env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DW_ENV", "local")
    monkeypatch.setenv("DW_TABLE_NAME", "DualWeatherTest")
    monkeypatch.setenv("DW_AUTH0_DOMAIN", "test.auth0.com")
    monkeypatch.setenv("DW_AUTH0_AUDIENCE", "https://api.dualweather/")
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")
    monkeypatch.setenv("AWS_DEFAULT_REGION", "us-east-2")
    get_settings.cache_clear()


@pytest.fixture
def moto_dynamo():
    """Spin up a moto DynamoDB and create the DualWeatherTest table."""
    with mock_aws():
        client = boto3.client("dynamodb", region_name="us-east-2")
        client.create_table(
            TableName="DualWeatherTest",
            BillingMode="PAY_PER_REQUEST",
            AttributeDefinitions=[
                {"AttributeName": "pk", "AttributeType": "S"},
                {"AttributeName": "sk", "AttributeType": "S"},
            ],
            KeySchema=[
                {"AttributeName": "pk", "KeyType": "HASH"},
                {"AttributeName": "sk", "KeyType": "RANGE"},
            ],
        )
        yield boto3.resource("dynamodb", region_name="us-east-2").Table("DualWeatherTest")


@pytest.fixture
def settings(monkeypatch) -> Settings:
    # Force settings to talk to real (mocked) AWS, not DynamoDB Local
    monkeypatch.setenv("DW_ENV", "prod")
    get_settings.cache_clear()
    return Settings()
