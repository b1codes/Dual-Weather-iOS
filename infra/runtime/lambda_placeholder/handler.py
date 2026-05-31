def handler(event, context):
    return {
        "statusCode": 500,
        "body": '{"type":"https://dualweather.app/errors/not-deployed","title":"Backend code not deployed","status":500,"detail":"Run `make deploy` from backend/ to upload real backend code."}',
        "headers": {"content-type": "application/json"},
    }
