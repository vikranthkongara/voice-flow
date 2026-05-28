# Voice Flow Mobile

## Architecture

Mobile integration uses a different approach since iOS/Android can't run Python directly.

### Option A: Companion App (Recommended)
- Native iOS/Android app with built-in speech recognition
- Sends raw transcript to a backend Lambda for Bedrock cleanup
- Returns cleaned text to the mobile keyboard/clipboard

### Option B: Keyboard Extension
- Custom keyboard that includes a mic button
- Hold mic → record → transcribe → insert cleaned text inline
- iOS: Custom Keyboard Extension (Swift)
- Android: Input Method Service (Kotlin)

## Tech Stack

| Component | iOS | Android |
|-----------|-----|---------|
| Speech capture | AVAudioEngine | AudioRecord |
| Local STT | Apple Speech Framework / Whisper.cpp | Android SpeechRecognizer / Whisper.cpp |
| Bedrock cleanup | HTTPS → API Gateway → Lambda | Same |
| Text injection | UIPasteboard + UITextInput | ClipboardManager + InputConnection |

## Project Structure (planned)

```
mobile/
├── ios/
│   ├── VoiceFlow/           # SwiftUI app
│   └── VoiceFlowKeyboard/   # Keyboard extension
├── android/
│   ├── app/                  # Kotlin app
│   └── keyboard/             # IME service
└── backend/
    └── lambda/               # Bedrock cleanup Lambda (shared)
```

## Backend Lambda (shared by all mobile clients)

```python
# lambda_handler.py
import json
import boto3

bedrock = boto3.client("bedrock-runtime", region_name="us-west-2")

def handler(event, context):
    body = json.loads(event["body"])
    transcript = body["transcript"]

    response = bedrock.invoke_model(
        modelId="anthropic.claude-sonnet-4-6-v1:0",
        contentType="application/json",
        accept="application/json",
        body=json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 1024,
            "messages": [{"role": "user", "content": f"Clean up this speech transcript. Fix grammar, remove filler words, fix punctuation. Return ONLY the cleaned text.\n\nTranscript: {transcript}"}],
        }),
    )
    result = json.loads(response["body"].read())
    cleaned = result["content"][0]["text"].strip()

    return {
        "statusCode": 200,
        "body": json.dumps({"cleaned": cleaned}),
    }
```

## Status: Planned

Desktop (Mac/Win/Linux) ships first. Mobile follows once the backend Lambda is deployed.
