import json
import os

import boto3

bedrock = boto3.client("bedrock-runtime")
table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])

CATEGORIES = {"BILLING", "BUG", "ACCOUNT", "SHIPPING", "OTHER"}
PRIORITIES = {"LOW", "MEDIUM", "HIGH"}

PROMPT = (
    "Classify this support ticket. Reply with JSON only, no other text, in the form "
    '{"category": "...", "priority": "...", "summary": "..."}. '
    "category must be exactly one of BILLING, BUG, ACCOUNT, SHIPPING, OTHER. "
    "priority must be exactly one of LOW, MEDIUM, HIGH. "
    "summary is one sentence.\n\nTicket:\n"
)


def parse_triage(text):
    # Bad AI output must never crash the batch, so fall back to safe defaults.
    result = {"category": "OTHER", "priority": "MEDIUM", "summary": ""}
    try:
        data = json.loads(text[text.index("{"): text.rindex("}") + 1])
        # Only values from the fixed allow-lists are stored; anything else keeps the default.
        category = str(data.get("category")).strip().upper()
        if category in CATEGORIES:
            result["category"] = category
        priority = str(data.get("priority")).strip().upper()
        if priority in PRIORITIES:
            result["priority"] = priority
        if isinstance(data.get("summary"), str):
            result["summary"] = data["summary"]
    except (ValueError, AttributeError):
        pass
    return result


def handler(event, context):
    for record in event["Records"]:
        image = record["dynamodb"].get("NewImage", {})

        # Loop guard: our own update is a stream event too, so skip tickets already triaged.
        if record["eventName"] != "INSERT" or "triage_category" in image:
            continue

        subject = image.get("subject", {}).get("S", "")
        message = image.get("message", {}).get("S", "")
        ticket_text = f"{subject}\n{message}"[:1000]

        response = bedrock.converse(
            modelId=os.environ["MODEL_ID"],
            messages=[{"role": "user", "content": [{"text": PROMPT + ticket_text}]}],
            inferenceConfig={"maxTokens": 150, "temperature": 0},
        )
        content = response["output"]["message"]["content"]
        triage = parse_triage(content[0].get("text", "") if content else "")

        table.update_item(
            Key={"ticket_id": image["ticket_id"]["S"]},
            UpdateExpression=(
                "SET triage_category = :c, triage_priority = :p, "
                "triage_summary = :s, #status = :status"
            ),
            ExpressionAttributeNames={"#status": "status"},
            ExpressionAttributeValues={
                ":c": triage["category"],
                ":p": triage["priority"],
                ":s": triage["summary"],
                ":status": "PENDING_APPROVAL",
            },
        )
