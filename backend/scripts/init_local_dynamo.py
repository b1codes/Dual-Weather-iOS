"""Create the DualWeather table in the local DynamoDB instance.

Run after `docker compose up -d`. Safe to run repeatedly — it's a no-op if the
table already exists.
"""

from __future__ import annotations

import boto3
from botocore.exceptions import ClientError


TABLE_NAME = "DualWeather"
ENDPOINT_URL = "http://localhost:8001"
REGION = "us-east-2"


def main() -> None:
    client = boto3.client(
        "dynamodb",
        endpoint_url=ENDPOINT_URL,
        region_name=REGION,
        aws_access_key_id="local",
        aws_secret_access_key="local",
    )

    try:
        client.describe_table(TableName=TABLE_NAME)
        print(f"Table {TABLE_NAME!r} already exists — nothing to do.")
        return
    except ClientError as exc:
        if exc.response["Error"]["Code"] != "ResourceNotFoundException":
            raise

    client.create_table(
        TableName=TABLE_NAME,
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

    waiter = client.get_waiter("table_exists")
    waiter.wait(TableName=TABLE_NAME)
    print(f"Created table {TABLE_NAME!r}.")


if __name__ == "__main__":
    main()
