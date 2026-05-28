#!/bin/bash
# Cross-platform first-run setup for Voice Flow

OS="$(uname -s)"

echo "============================================"
echo "        Voice Flow - First Time Setup       "
echo "============================================"
echo ""
echo "Platform detected: $OS"
echo ""

# Check Python 3
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is required."
    case "$OS" in
        Darwin) echo "  Install: brew install python@3.11" ;;
        Linux)  echo "  Install: sudo apt install python3 python3-venv" ;;
        MINGW*|MSYS*|CYGWIN*) echo "  Install: Download from python.org" ;;
    esac
    exit 1
fi
echo "[OK] Python 3 found"

# Check AWS credentials for Bedrock
if command -v aws &> /dev/null && aws sts get-caller-identity &> /dev/null; then
    echo "[OK] AWS credentials active"
else
    echo "[WARN] No active AWS credentials. Run 'mwinit' or configure credentials."
    echo "       Voice Flow uses Bedrock (us-west-2) for text cleanup."
    echo "       (voice-flow-local works without credentials)"
fi

echo ""

case "$OS" in
    Darwin)
        echo "macOS Setup:"
        echo "  1. Grant Microphone access to your terminal app"
        echo "  2. Grant Accessibility access to your terminal app"
        echo ""
        echo "Opening System Settings..."
        open "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone" 2>/dev/null
        echo "  Press Enter after granting Microphone access..."
        read -r
        open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null
        echo "  Press Enter after granting Accessibility access..."
        read -r
        ;;
    Linux)
        echo "Linux Setup:"
        MISSING=""

        # Check clipboard
        if ! command -v xclip &>/dev/null && ! command -v xsel &>/dev/null && ! command -v wl-copy &>/dev/null; then
            MISSING="$MISSING xclip"
        else
            echo "[OK] Clipboard tool found"
        fi

        # Check paste tool
        SESSION_TYPE="${XDG_SESSION_TYPE:-x11}"
        if [ "$SESSION_TYPE" = "wayland" ]; then
            if ! command -v ydotool &>/dev/null; then
                MISSING="$MISSING ydotool"
            else
                echo "[OK] ydotool found (Wayland)"
            fi
        else
            if ! command -v xdotool &>/dev/null; then
                MISSING="$MISSING xdotool"
            else
                echo "[OK] xdotool found (X11)"
            fi
        fi

        # Check audio
        if ! python3 -c "import sounddevice" 2>/dev/null; then
            MISSING="$MISSING portaudio19-dev"
        fi

        if [ -n "$MISSING" ]; then
            echo ""
            echo "Missing packages. Install with:"
            echo "  sudo apt install$MISSING"
            echo ""
        fi
        ;;
    MINGW*|MSYS*|CYGWIN*)
        echo "Windows Setup:"
        echo "  No additional permissions needed."
        echo "  Clipboard and paste injection work out of the box."
        echo ""
        ;;
esac

echo ""
echo "Setup complete! Usage:"
echo "  voice-flow        - With Bedrock AI cleanup"
echo "  voice-flow-local  - Offline, Whisper only (faster)"
echo ""
echo "Hold Right Alt/Option to record, release to paste."
