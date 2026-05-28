# Voice Flow

<p align="center">
  <img src="logo.svg" width="120" alt="Voice Flow Logo">
</p>

**System-wide voice-to-text for every platform.** Hold a key, speak, release — cleaned text appears wherever your cursor is.

## Platforms

| Platform | Status | Input Method |
|----------|--------|-------------|
| macOS | Ready | Hold Right Option |
| Windows | Ready | Hold Right Alt |
| Linux (X11/Wayland) | Ready | Hold Right Alt |
| iOS | Beta | Hold mic button / Keyboard extension |
| Android | Beta | Hold mic button / IME keyboard |

## How It Works

```
Voice ─▶ Whisper (local STT) ─▶ Bedrock Claude (cleanup) ─▶ Paste
```

1. **Hold hotkey** — records from microphone
2. **Release** — Whisper transcribes locally on-device
3. **Bedrock Claude** cleans grammar, filler words, punctuation
4. **Pastes** cleaned text into the active app

## Quick Start (Desktop)

```bash
git clone git@github.com:vikranthkongara/voice-flow.git
cd voice-flow
./run.sh
```

### Prerequisites
- Python 3.8+
- AWS credentials configured (for Bedrock access)
- Platform-specific:
  - **macOS**: Grant Microphone + Accessibility permissions
  - **Linux**: `sudo apt install xclip xdotool portaudio19-dev`
  - **Windows**: No extra setup needed

### Offline Mode (no network)

```bash
python voice_flow_local.py
```

Uses Whisper only — faster, fully offline, slightly less polished output.

## Mobile

Mobile apps use on-device speech recognition + a shared Lambda backend for Bedrock cleanup.

### Deploy Backend

```bash
./deploy.sh
```

### iOS
- SwiftUI standalone app (hold to speak)
- Custom keyboard extension (dictate directly into any app)
- Uses Apple Speech Framework for on-device STT

### Android
- Jetpack Compose standalone app
- Input Method Service (IME) keyboard with mic button
- Uses Android SpeechRecognizer for on-device STT

## Architecture

```
┌──────────────────────────────────────────────────┐
│                   Desktop                         │
│  Hotkey ─▶ Mic ─▶ Whisper ─▶ Bedrock ─▶ Paste   │
└──────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────┐
│                   Mobile                          │
│  Hold Mic ─▶ On-device STT ─▶ Lambda ─▶ Insert   │
│                                  │               │
│                           Bedrock Claude         │
└──────────────────────────────────────────────────┘
```

## Configuration

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `VOICE_FLOW_WHISPER_MODEL` | `base` | Whisper model size (tiny/base/small/medium/large) |
| `VOICE_FLOW_BEDROCK_MODEL` | `anthropic.claude-sonnet-4-6-v1:0` | Bedrock model ID |
| `VOICE_FLOW_BEDROCK_REGION` | `us-west-2` | AWS region for Bedrock |

## Security

- Audio never leaves your device (desktop) or phone (mobile)
- Only text transcripts are sent to Bedrock (via internal AWS infrastructure)
- No external API calls — all inference routes through Bedrock
- Lambda backend is stateless — no data stored
- Mobile audio processing is fully on-device (Apple Speech / Android SpeechRecognizer)

## Distribution

Packaged for [Builder Toolbox](https://docs.hub.amazon.dev/docs/builder-toolbox/) distribution:

```bash
toolbox install voice-flow
voice-flow-setup   # first-run permissions
voice-flow         # start dictating
```
