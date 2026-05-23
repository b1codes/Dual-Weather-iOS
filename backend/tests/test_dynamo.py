import boto3
from moto import mock_aws

from dual_weather.dynamo import get_table
from dual_weather.settings import Settings


@mock_aws
def test_get_table_returns_table_resource(monkeypatch):
    monkeypatch.setenv("DW_ENV", "prod")
    monkeypatch.setenv("DW_TABLE_NAME", "DualWeather")

    client = boto3.client("dynamodb", region_name="us-east-2")
    client.create_table(
        TableName="DualWeather",
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

    settings = Settings()
    table = get_table(settings)

    assert table.name == "DualWeather"
    # Sanity round-trip
    table.put_item(Item={"pk": "X", "sk": "Y"})
    item = table.get_item(Key={"pk": "X", "sk": "Y"})["Item"]
    assert item == {"pk": "X", "sk": "Y"}
