# Voice Flow Mobile

Cross-platform mobile voice-to-text with Bedrock AI cleanup.

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌──────────────────┐
│   iOS App   │     │ Android App │     │  Lambda Backend  │
│             │     │             │     │                  │
│ Speech FW   │────▶│ SpeechReco  │────▶│ Bedrock Claude   │
│ + Keyboard  │◀────│ + IME       │◀────│ Transcript Clean │
└─────────────┘     └─────────────┘     └──────────────────┘
```

## Components

### Backend (Lambda + API Gateway)
- `backend/lambda_handler.py` — Bedrock cleanup function
- `backend/template.yaml` — SAM template for deployment
- Deploy: `cd backend && sam build && sam deploy --guided`

### iOS
- `ios/VoiceFlow/` — SwiftUI standalone app (hold to speak, shows result)
- `ios/VoiceFlowKeyboard/` — Custom keyboard extension (hold mic, inserts text inline)
- Uses Apple Speech Framework for on-device STT
- Sends transcript to Lambda for Bedrock cleanup

### Android
- `android/app/` — Jetpack Compose standalone app
- `android/keyboard/` — Input Method Service (IME) with mic button
- Uses Android SpeechRecognizer for on-device STT
- Sends transcript to Lambda for Bedrock cleanup

## Setup

### 1. Deploy Backend

```bash
cd mobile/backend
sam build
sam deploy --guided \
  --stack-name voice-flow-backend \
  --capabilities CAPABILITY_IAM \
  --region us-west-2
```

Note the API Gateway URL from the output.

### 2. Update Client Endpoints

Replace `YOUR_API_GATEWAY_URL` in:
- `ios/VoiceFlow/VoiceRecorder.swift`
- `ios/VoiceFlowKeyboard/KeyboardViewController.swift`
- `android/app/src/main/kotlin/com/voiceflow/VoiceFlowApi.kt`

### 3. Build iOS

```bash
cd ios
open VoiceFlow.xcodeproj
# Set team, build for device
```

### 4. Build Android

```bash
cd android
./gradlew assembleDebug
```

## How It Works

1. User holds mic button (in app or keyboard)
2. On-device speech recognition transcribes in real-time
3. On release, raw transcript sent to Lambda
4. Lambda calls Bedrock Claude to clean grammar/filler words
5. Cleaned text returned and inserted at cursor (keyboard) or copied to clipboard (app)

## Security

- Audio never leaves device — only text transcript sent to backend
- Backend Lambda uses IAM role with minimal Bedrock permissions
- API Gateway can be locked down with API keys or Cognito auth
- No data stored — Lambda is stateless
