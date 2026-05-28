"""Voice Flow Local: Cross-platform voice-to-text (no network calls).
Uses Whisper only — faster, fully offline."""

import os
import platform
import tempfile
import threading
import subprocess
import numpy as np
import sounddevice as sd
import whisper
from pynput import keyboard


SAMPLE_RATE = 16000
MODEL_SIZE = os.environ.get("VOICE_FLOW_WHISPER_MODEL", "small")
HOTKEY = keyboard.Key.alt_r

PLATFORM = platform.system()

whisper_model = None
audio_frames = []


def load_whisper():
    global whisper_model
    print("Loading Whisper model...")
    whisper_model = whisper.load_model(MODEL_SIZE)
    print(f"Whisper '{MODEL_SIZE}' loaded on {PLATFORM}.")


def stop_recording():
    print("Transcribing...")

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
        copy_to_clipboard(text)
        paste_from_clipboard()
        print("Pasted!")
    finally:
        os.unlink(temp_path)


def copy_to_clipboard(text: str):
    if PLATFORM == "Darwin":
        process = subprocess.Popen(["pbcopy"], stdin=subprocess.PIPE)
        process.communicate(text.encode("utf-8"))
    elif PLATFORM == "Windows":
        process = subprocess.Popen(["clip.exe"], stdin=subprocess.PIPE)
        process.communicate(text.encode("utf-16le"))
    else:
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
        user32 = ctypes.windll.user32
        VK_CONTROL = 0x11
        VK_V = 0x56
        KEYEVENTF_KEYUP = 0x0002
        user32.keybd_event(VK_CONTROL, 0, 0, 0)
        user32.keybd_event(VK_V, 0, 0, 0)
        user32.keybd_event(VK_V, 0, KEYEVENTF_KEYUP, 0)
        user32.keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, 0)
    else:
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


def get_hotkey_name():
    if PLATFORM == "Darwin":
        return "Right Option"
    return "Right Alt"


def main():
    load_whisper()

    hotkey_name = get_hotkey_name()
    print(f"\nVoice Flow Local ready! ({PLATFORM})")
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
