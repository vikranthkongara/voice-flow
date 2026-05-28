#!/bin/bash
# Setup and run Voice Flow on macOS

set -e
cd "$(dirname "$0")"

if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
else
    source .venv/bin/activate
fi

echo ""
echo "NOTE: On first run, grant these macOS permissions:"
echo "  - Microphone access (System Settings > Privacy > Microphone)"
echo "  - Accessibility access (System Settings > Privacy > Accessibility)"
echo "    (needed for key listening and paste injection)"
echo ""

python voice_flow.py
