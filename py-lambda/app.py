import json
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Parse incoming JSON body from API Gateway
        body = json.loads(event.get("body", "{}"))
        user_id = body.get("id")
        name = body.get("name")

        if not user_id or not name:
            return {
                "statusCode": 400,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": 'Missing "id" or "name"'}),
            }

        # Return mock success response
        logger.info(f"Processing user: {user_id}, {name}")
        
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "message": "User processed successfully by Python Lambda",
                "user": {"id": user_id, "name": name},
                "note": "Demo response - PostgreSQL database not configured"
            }),
        }

    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "error": "Internal server error",
                "message": str(e),
                "type": type(e).__name__
            })
        }