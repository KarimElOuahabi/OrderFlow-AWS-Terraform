import json
import os

import boto3

ses = boto3.client("ses")
SENDER = os.environ["SENDER_EMAIL"]


def handler(event, context):
    for record in event["Records"]:
        body = json.loads(record["body"])
        order = body["detail"]

        email = order.get("customerEmail")
        if not email:
            print(f"Order {order['orderId']} has no email, skipping")
            continue

        ses.send_email(
            Source=SENDER,
            Destination={"ToAddresses": [email]},
            Message={
                "Subject": {"Data": "Your OrderFlow order is confirmed"},
                "Body": {
                    "Text": {
                        "Data": f"Order {order['orderId']} for {order['totalAmount']} was received."
                    }
                },
            },
        )