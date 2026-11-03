import json
import os

import boto3
from botocore.exceptions import ClientError

table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])


def handler(event, context):
    for record in event["Records"]:
        body = json.loads(record["body"])

        try:
            table.put_item(
                Item={
                    "event_id": body["id"],
                    "detail_type": body["detail-type"],
                    "detail": json.dumps(body["detail"]),
                },
                ConditionExpression="attribute_not_exists(event_id)",
            )
        except ClientError as e:
            if e.response["Error"]["Code"] != "ConditionalCheckFailedException":
                raise
            print(f"Duplicate event {body['id']}, skipping")