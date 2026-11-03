import json
import os
import uuid
from datetime import datetime, timezone

import boto3

table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])


def response(status, body):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def handler(event, context):
    # The customer comes from the verified JWT, never from the request body.
    claims = event["requestContext"]["authorizer"]["jwt"]["claims"]

    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return response(400, {"error": "body must be valid JSON"})
    if not isinstance(body, dict):
        return response(400, {"error": "body must be a JSON object"})

    subject = body.get("subject")
    message = body.get("message")
    if not isinstance(subject, str) or not subject.strip():
        return response(400, {"error": "subject is required"})
    if not isinstance(message, str) or not message.strip():
        return response(400, {"error": "message is required"})

    ticket_id = str(uuid.uuid4())
    table.put_item(
        Item={
            "ticket_id": ticket_id,
            "customer_id": claims["sub"],
            "customer_email": claims.get("email"),
            "subject": subject,
            "message": message,
            "status": "OPEN",
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
    )
    return response(201, {"ticketId": ticket_id})
