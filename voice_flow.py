"""Voice Flow: Cross-platform voice-to-text tool (macOS, Windows, Linux).
Hold a hotkey to record, release to transcribe and paste cleaned text via Bedrock."""

import os
import sys
import platform
import tempfile
import threading
import subprocess
import json
import numpy as np
import sounddevice as sd
import whisper
import boto3
from pynput import keyboard


SAMPLE_RATE = 16000
MODEL_SIZE = os.environ.get("VOICE_FLOW_WHISPER_MODEL", "base")
BEDROCK_MODEL = os.environ.get("VOICE_FLOW_BEDROCK_MODEL", "anthropic.claude-sonnet-4-6-v1:0")
BEDROCK_REGION = os.environ.get("VOICE_FLOW_BEDROCK_REGION", "us-west-2")
HOTKEY = keyboard.Key.alt_r  # Right Alt/Option on all platforms

PLATFORM = platform.system()  # Darwin, Windows, Linux

whisper_model = None
audio_frames = []


def load_whisper():
    global whisper_model
    print("Loading Whisper model...")
    whisper_model = whisper.load_model(MODEL_SIZE)
    print(f"Whisper '{MODEL_SIZE}' loaded on {PLATFORM}.")


def stop_recording():
    print("Processing...")

    if not audio_frames:
        print("No audio captured.")
        return

    audio = np.concatenate(audio_frames, axis=0).flatten()

    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        import scipy.io.wavfile
        scipy.io.wavfile.write(f.name, SAMPLE_RATE, (audio * 32767).astype(np.int16))
        temp_path = f.name

    try:
        result = whisper_model.transcribe(temp_path, language="en")
        raw_text = result["text"].strip()

        if not raw_text:
            print("No speech detected.")
            return

        print(f"Raw: {raw_text}")
        cleaned = clean_with_claude(raw_text)
        print(f"Clean: {cleaned}")
        copy_to_clipboard(cleaned)
        paste_from_clipboard()
        print("Pasted!")
    finally:
        os.unlink(temp_path)


def clean_with_claude(text: str) -> str:
    client = boto3.client("bedrock-runtime", region_name=BEDROCK_REGION)
    response = client.invoke_model(
        modelId=BEDROCK_MODEL,
        contentType="application/json",
        accept="application/json",
        body=json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 1024,
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
    result = json.loads(response["body"].read())
    return result["content"][0]["text"].strip()


def copy_to_clipboard(text: str):
    if PLATFORM == "Darwin":
        process = subprocess.Popen(["pbcopy"], stdin=subprocess.PIPE)
        process.communicate(text.encode("utf-8"))
    elif PLATFORM == "Windows":
        process = subprocess.Popen(["clip.exe"], stdin=subprocess.PIPE)
        process.communicate(text.encode("utf-16le"))
    else:
        # Linux: try xclip, then xsel, then wl-copy (Wayland)
        for cmd in [["xclip", "-selection", "clipboard"], ["xsel", "--clipboard", "--input"], ["wl-copy"]]:
            try:
                process = subprocess.Popen(cmd, stdin=subprocess.PIPE)
                process.communicate(text.encode("utf-8"))
                return
            except FileNotFoundError:
                continue
        print("WARNING: No clipboard tool found. Install xclip, xsel, or wl-copy.")


def paste_from_clipboard():
    if PLATFORM == "Darwin":
        subprocess.run(
            ["osascript", "-e", 'tell application "System Events" to keystroke "v" using command down'],
        )
    elif PLATFORM == "Windows":
        import ctypes
        from ctypes import wintypes
        user32 = ctypes.windll.user32
        VK_CONTROL = 0x11
        VK_V = 0x56
        KEYEVENTF_KEYUP = 0x0002
        user32.keybd_event(VK_CONTROL, 0, 0, 0)
        user32.keybd_event(VK_V, 0, 0, 0)
        user32.keybd_event(VK_V, 0, KEYEVENTF_KEYUP, 0)
        user32.keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, 0)
    else:
        # Linux: xdotool for X11, ydotool for Wayland
        session_type = os.environ.get("XDG_SESSION_TYPE", "x11")
        if session_type == "wayland":
            subprocess.run(["ydotool", "key", "29:1", "47:1", "47:0", "29:0"], capture_output=True)
        else:
            subprocess.run(["xdotool", "key", "ctrl+v"], capture_output=True)


class HotkeyListener:
    def __init__(self):
        self.hotkey_pressed = False
        self.stream = None

    def on_press(self, key):
        if key == HOTKEY:
            if not self.hotkey_pressed:
                self.hotkey_pressed = True
                self.stream = sd.InputStream(
                    samplerate=SAMPLE_RATE,
                    channels=1,
                    dtype="float32",
                    callback=self._audio_callback,
                )
                audio_frames.clear()
                self.stream.start()
                print("Recording...")

    def on_release(self, key):
        if key == HOTKEY:
            if self.hotkey_pressed:
                self.hotkey_pressed = False
                if self.stream:
                    self.stream.stop()
                    self.stream.close()
                    self.stream = None
                threading.Thread(target=stop_recording, daemon=True).start()

    def _audio_callback(self, indata, frames, time, status):
        audio_frames.append(indata.copy())


def check_platform_deps():
    issues = []

    if PLATFORM == "Linux":
        has_clipboard = False
        for cmd in ["xclip", "xsel", "wl-copy"]:
            if subprocess.run(["which", cmd], capture_output=True).returncode == 0:
                has_clipboard = True
                break
        if not has_clipboard:
            issues.append("No clipboard tool found. Install: sudo apt install xclip")

        session_type = os.environ.get("XDG_SESSION_TYPE", "x11")
        paste_tool = "ydotool" if session_type == "wayland" else "xdotool"
        if subprocess.run(["which", paste_tool], capture_output=True).returncode != 0:
            issues.append(f"No paste tool found. Install: sudo apt install {paste_tool}")

    if issues:
        print("Missing dependencies:")
        for issue in issues:
            print(f"  - {issue}")
        print()

    return len(issues) == 0


def get_hotkey_name():
    if PLATFORM == "Darwin":
        return "Right Option"
    return "Right Alt"


def main():
    check_platform_deps()
    load_whisper()

    hotkey_name = get_hotkey_name()
    print(f"\nVoice Flow ready! ({PLATFORM})")
    print(f"Hold {hotkey_name} to record, release to transcribe and paste.")
    print("Press Ctrl+C to quit.\n")

    listener = HotkeyListener()
    with keyboard.Listener(
        on_press=listener.on_press,
        on_release=listener.on_release,
    ) as l:
        l.join()


if __name__ == "__main__":
    main()
