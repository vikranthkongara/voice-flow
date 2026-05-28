#!/bin/bash
# Cross-platform setup and run for Voice Flow

set -e
cd "$(dirname "$0")"

OS="$(uname -s)"

if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv .venv

    case "$OS" in
        Darwin)
            source .venv/bin/activate
            ;;
        Linux)
            source .venv/bin/activate
            ;;
        MINGW*|MSYS*|CYGWIN*)
            source .venv/Scripts/activate
            ;;
    esac

    pip install -r requirements.txt
else
    case "$OS" in
        Darwin)
            source .venv/bin/activate
            ;;
        Linux)
            source .venv/bin/activate
            ;;
        MINGW*|MSYS*|CYGWIN*)
            source .venv/Scripts/activate
            ;;
    esac
fi

echo ""
echo "=== Voice Flow ==="
echo "Platform: $OS"
echo ""

case "$OS" in
    Darwin)
        echo "macOS permissions needed:"
        echo "  - Microphone (System Settings > Privacy > Microphone)"
        echo "  - Accessibility (System Settings > Privacy > Accessibility)"
        ;;
    Linux)
        echo "Linux dependencies needed:"
        echo "  - Audio: pulseaudio or pipewire"
        echo "  - Clipboard: xclip, xsel, or wl-copy"
        echo "  - Paste: xdotool (X11) or ydotool (Wayland)"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        echo "Windows: no extra setup needed."
        ;;
esac

echo ""
python voice_flow.py
