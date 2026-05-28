"""Voice Flow Backend Lambda — cleans speech transcripts via Bedrock.
Shared by iOS and Android clients."""

import json
import os
import boto3

BEDROCK_MODEL = os.environ.get("BEDROCK_MODEL", "anthropic.claude-sonnet-4-6-v1:0")
BEDROCK_REGION = os.environ.get("BEDROCK_REGION", "us-west-2")

bedrock = boto3.client("bedrock-runtime", region_name=BEDROCK_REGION)


def handler(event, context):
    try:
        body = json.loads(event.get("body", "{}"))
        transcript = body.get("transcript", "").strip()

        if not transcript:
            return response(400, {"error": "Missing 'transcript' field"})

        if len(transcript) > 10000:
            return response(400, {"error": "Transcript too long (max 10000 chars)"})

        cleaned = clean_transcript(transcript)
        return response(200, {"cleaned": cleaned})

    except json.JSONDecodeError:
        return response(400, {"error": "Invalid JSON body"})
    except Exception as e:
        return response(500, {"error": f"Internal error: {str(e)}"})


def clean_transcript(text: str) -> str:
    resp = bedrock.invoke_model(
        modelId=BEDROCK_MODEL,
        contentType="application/json",
        accept="application/json",
        body=json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 2048,
            "messages": [
                {
                    "role": "user",
                    "content": (
                        "Clean up this speech transcript. Fix grammar, remove filler words "
                        "(um, uh, like, you know), fix punctuation, and make it read naturally. "
                        "Do NOT change the meaning or add information. Return ONLY the cleaned text, "
                        "nothing else.\n\n"
                        f"Transcript: {text}"
                    ),
                }
            ],
        }),
    )
    result = json.loads(resp["body"].read())
    return result["content"][0]["text"].strip()


def response(status_code: int, body: dict) -> dict:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body),
    }
