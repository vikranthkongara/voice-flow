"""Voice-to-text tool for macOS. Hold Option key to record, release to transcribe and paste."""

import os
import tempfile
import threading
import subprocess
import numpy as np
import sounddevice as sd
import whisper
import boto3
import json
from pynput import keyboard


SAMPLE_RATE = 16000
MODEL_SIZE = "base"  # Options: tiny, base, small, medium, large
BEDROCK_MODEL = "anthropic.claude-sonnet-4-6-v1:0"
BEDROCK_REGION = "us-west-2"

whisper_model = None
recording = False
audio_frames = []


def load_whisper():
    global whisper_model
    print("Loading Whisper model...")
    whisper_model = whisper.load_model(MODEL_SIZE)
    print(f"Whisper '{MODEL_SIZE}' loaded.")


def start_recording():
    global recording, audio_frames
    audio_frames = []
    recording = True
    print("🎙️  Recording...")

    def callback(indata, frames, time, status):
        if recording:
            audio_frames.append(indata.copy())

    sd.InputStream(
        samplerate=SAMPLE_RATE,
        channels=1,
        dtype="float32",
        callback=callback,
    ).start()


def stop_recording():
    global recording
    recording = False
    print("⏹️  Processing...")

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
        paste_text(cleaned)
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


def paste_text(text: str):
    process = subprocess.Popen(["pbcopy"], stdin=subprocess.PIPE)
    process.communicate(text.encode("utf-8"))
    subprocess.run(
        ["osascript", "-e", 'tell application "System Events" to keystroke "v" using command down'],
    )
    print("✅ Pasted!")


class HotkeyListener:
    def __init__(self):
        self.option_pressed = False
        self.stream = None

    def on_press(self, key):
        if key == keyboard.Key.alt_l or key == keyboard.Key.alt_r:
            if not self.option_pressed:
                self.option_pressed = True
                self.stream = sd.InputStream(
                    samplerate=SAMPLE_RATE,
                    channels=1,
                    dtype="float32",
                    callback=self._audio_callback,
                )
                audio_frames.clear()
                self.stream.start()
                print("🎙️  Recording...")

    def on_release(self, key):
        if key == keyboard.Key.alt_l or key == keyboard.Key.alt_r:
            if self.option_pressed:
                self.option_pressed = False
                if self.stream:
                    self.stream.stop()
                    self.stream.close()
                    self.stream = None
                threading.Thread(target=stop_recording, daemon=True).start()

    def _audio_callback(self, indata, frames, time, status):
        audio_frames.append(indata.copy())


def main():
    load_whisper()
    print("\n✅ Voice Flow ready!")
    print("Hold Option (⌥) to record, release to transcribe and paste.")
    print("Press Ctrl+C to quit.\n")

    listener = HotkeyListener()
    with keyboard.Listener(
        on_press=listener.on_press,
        on_release=listener.on_release,
    ) as l:
        l.join()


if __name__ == "__main__":
    main()
