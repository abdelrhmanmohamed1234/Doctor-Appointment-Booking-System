import json
import boto3
import os

dynamodb = boto3.resource("dynamodb")
sns = boto3.client("sns")

BOOKINGS_TABLE = os.environ.get("BOOKINGS_TABLE")
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN")

table = dynamodb.Table(BOOKINGS_TABLE)

def respond(status, body):
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps(body)
    }

def create_booking(body):
    booking_id = f"{body.get('patient_name')}-{body.get('date')}-{body.get('time')}"
    booking_item = {
        "booking_id": booking_id,
        "patient_name": body.get("patient_name"),
        "date": body.get("date"),
        "time": body.get("time")
    }
    table.put_item(Item=booking_item)
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Message=f"New booking created: {booking_item}"
    )
    return respond(200, {"message": "Booking created", "booking": booking_item})

def lambda_handler(event, context):
    http_method = event.get("httpMethod", "")
    path = event.get("path", "")
    body = {}

    if event.get("body"):
        try:
            body = json.loads(event["body"])
        except Exception:
            body = {}

    if http_method == "OPTIONS":
        return respond(200, {"message": "CORS preflight OK"})

    if http_method == "POST" and path.endswith("/book"):
        return create_booking(body)

    return respond(400, {"error": "Unknown route or method"})

