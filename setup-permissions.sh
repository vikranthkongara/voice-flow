#!/bin/bash
# First-run setup: guide user through macOS permission grants

echo "╔══════════════════════════════════════════════╗"
echo "║         Voice Flow - First Time Setup        ║"
echo "╠══════════════════════════════════════════════╣"
echo "║                                              ║"
echo "║  Voice Flow needs two macOS permissions:     ║"
echo "║                                              ║"
echo "║  1. Microphone Access                        ║"
echo "║     (to capture your voice)                  ║"
echo "║                                              ║"
echo "║  2. Accessibility Access                     ║"
echo "║     (to listen for hotkey + paste text)      ║"
echo "║                                              ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "ERROR: Voice Flow only supports macOS."
    exit 1
fi

# Check Python 3
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is required. Install via: brew install python@3.11"
    exit 1
fi

# Check AWS credentials for Bedrock
echo "Checking AWS credentials for Bedrock..."
if aws sts get-caller-identity &> /dev/null; then
    echo "  AWS credentials OK"
else
    echo "  WARNING: No active AWS credentials found."
    echo "  Voice Flow uses Bedrock (us-west-2) for text cleanup."
    echo "  Run 'mwinit' or configure Conduit before using voice-flow."
fi

echo ""
echo "Opening System Settings for permissions..."
echo ""

# Open Microphone settings
echo "Step 1: Grant Microphone access to Terminal/iTerm2"
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
echo "  Press Enter after granting Microphone access..."
read -r

# Open Accessibility settings
echo "Step 2: Grant Accessibility access to Terminal/iTerm2"
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
echo "  Press Enter after granting Accessibility access..."
read -r

echo ""
echo "Setup complete! Run 'voice-flow' to start."
echo ""
echo "Usage:"
echo "  voice-flow        - With Claude cleanup (needs Bedrock)"
echo "  voice-flow-local  - Whisper only (no network, faster)"
echo ""
echo "Hold Option key to record, release to transcribe and paste."
