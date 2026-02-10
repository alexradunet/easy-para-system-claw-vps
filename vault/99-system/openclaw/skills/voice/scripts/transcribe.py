#!/usr/bin/env python3
"""Transcribe audio files using local Whisper model."""

import sys
import os

# Use the venv's packages
VOICE_VENV = os.environ.get("VOICE_VENV", "/opt/voice-venv")
sys.path.insert(0, f"{VOICE_VENV}/lib/python3.13/site-packages")

from faster_whisper import WhisperModel

MODEL_ROOT = os.environ.get("WHISPER_MODEL_DIR", "/opt/models/whisper")

def transcribe(audio_path, model_size="small"):
    """Transcribe audio file to text."""
    if not os.path.exists(audio_path):
        print(f"Error: File not found: {audio_path}", file=sys.stderr)
        sys.exit(1)

    print(f"Loading Whisper model: {model_size}", file=sys.stderr)
    model = WhisperModel(model_size, device="cpu", compute_type="int8", download_root=MODEL_ROOT)

    print(f"Transcribing: {audio_path}", file=sys.stderr)
    segments, info = model.transcribe(audio_path, beam_size=5)

    print(f"Language: {info.language} (probability: {info.language_probability:.2f})", file=sys.stderr)

    full_text = []
    for segment in segments:
        print(f"[{segment.start:.2f}s -> {segment.end:.2f}s] {segment.text}")
        full_text.append(segment.text)

    return " ".join(full_text)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: transcribe.py <audio_file> [model_size]", file=sys.stderr)
        print("Models: tiny, base, small (default), medium, large", file=sys.stderr)
        sys.exit(1)

    audio_file = sys.argv[1]
    model = sys.argv[2] if len(sys.argv) > 2 else "small"

    result = transcribe(audio_file, model)
    print("\n--- Full Transcription ---")
    print(result)
