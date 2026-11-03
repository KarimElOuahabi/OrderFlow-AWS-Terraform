import json
import os
import re
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])


def response(status, body):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def is_admin(claims):
    # API Gateway may deliver the groups claim as a list or as a string like "[admin]".
    groups = claims.get("cognito:groups", [])
    if isinstance(groups, str):
        groups = [g for g in re.split(r"[\s,]+", groups.strip("[] ")) if g]
    # Exact match on a group name, never a substring, so "superadmin" does not pass.
    return "admin" in groups


def handler(event, context):
    claims = event["requestContext"]["authorizer"]["jwt"]["claims"]
    if not is_admin(claims):
        return response(403, {"error": "admin only"})

    ticket_id = event["pathParameters"]["id"]
    try:
        # Conditional update: only a ticket waiting for approval can be approved,
        # so a ticket cannot be approved twice or before triage.
        table.update_item(
            Key={"ticket_id": ticket_id},
            UpdateExpression="SET #status = :approved, approved_by = :by, approved_at = :at",
            ConditionExpression="#status = :pending",
            ExpressionAttributeNames={"#status": "status"},
            ExpressionAttributeValues={
                ":approved": "APPROVED",
                ":pending": "PENDING_APPROVAL",
                ":by": claims["sub"],
                ":at": datetime.now(timezone.utc).isoformat(),
            },
        )
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return response(404, {"error": "ticket not found or not pending approval"})
        raise

    return response(200, {"ticketId": ticket_id, "status": "APPROVED"})
