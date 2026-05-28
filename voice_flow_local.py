"""Fully local version — no API calls. Uses Whisper for both transcription and cleanup.
Faster but less polished output (no Claude reformatting)."""

import os
import tempfile
import threading
import subprocess
import numpy as np
import sounddevice as sd
import whisper
from pynput import keyboard


SAMPLE_RATE = 16000
MODEL_SIZE = "small"  # Use 'small' or 'medium' for better accuracy without Claude

whisper_model = None
audio_frames = []


def load_whisper():
    global whisper_model
    print("Loading Whisper model...")
    whisper_model = whisper.load_model(MODEL_SIZE)
    print(f"Whisper '{MODEL_SIZE}' loaded.")


def stop_recording():
    print("⏹️  Transcribing...")

    if not audio_frames:
        print("No audio captured.")
        return

    audio = np.concatenate(audio_frames, axis=0).flatten()

    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        import scipy.io.wavfile
        scipy.io.wavfile.write(f.name, SAMPLE_RATE, (audio * 32767).astype(np.int16))
        temp_path = f.name

    try:
        result = whisper_model.transcribe(
            temp_path,
            language="en",
            initial_prompt="Clean, well-punctuated English text.",
        )
        text = result["text"].strip()

        if not text:
            print("No speech detected.")
            return

        print(f"Text: {text}")
        paste_text(text)
    finally:
        os.unlink(temp_path)


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
    print("\n✅ Voice Flow (local) ready!")
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
