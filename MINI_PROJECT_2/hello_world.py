import json


def handler(event, context):
    name = None

    if event.get("queryStringParameters"):
        name = event["queryStringParameters"].get("name")

    if not name and event.get("body"):
        try:
            body = json.loads(event["body"])
            name = body.get("name")
        except (json.JSONDecodeError, AttributeError):
            pass

    if not name:
        name = "World"

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps({"message": f"Hello, {name}!"})
    }
