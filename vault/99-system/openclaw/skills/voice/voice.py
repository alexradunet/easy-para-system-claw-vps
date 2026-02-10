"""Voice processing utilities for local STT and TTS with Obsidian integration."""

import sys
import os
import subprocess

# Add obsidian skill to path (relative to vault)
VAULT_PATH = os.environ.get("VAULT_PATH", "/vault")
sys.path.insert(0, os.path.join(VAULT_PATH, "99-system/openclaw/skills/obsidian"))

VOICE_VENV = os.environ.get("VOICE_VENV", "/opt/voice-venv")
sys.path.insert(0, f"{VOICE_VENV}/lib/python3.13/site-packages")

from faster_whisper import WhisperModel
from obsidian import append_to_daily_note, get_daily_note_path

WHISPER_ROOT = os.environ.get("WHISPER_MODEL_DIR", "/opt/models/whisper")
PIPER_MODEL = os.path.join(
    os.environ.get("PIPER_MODEL_DIR", "/opt/models/piper"),
    "en_US-lessac-medium.onnx"
)

def transcribe_audio(audio_path, model="small"):
    """
    Transcribe an audio file to text using Whisper.

    Args:
        audio_path: Path to audio file
        model: Model size (tiny, base, small, medium, large)

    Returns:
        Transcribed text string
    """
    model_obj = WhisperModel(model, device="cpu", compute_type="int8", download_root=WHISPER_ROOT)
    segments, _ = model_obj.transcribe(audio_path, beam_size=5)
    return " ".join([s.text for s in segments])

def transcribe_with_timestamp(audio_path, model="small"):
    """
    Transcribe audio and return text with current timestamp.

    Returns:
        Tuple of (timestamp_str, transcribed_text)
    """
    from datetime import datetime

    now = datetime.now()
    timestamp = now.strftime("%H:%M")

    model_obj = WhisperModel(model, device="cpu", compute_type="int8", download_root=WHISPER_ROOT)
    segments, _ = model_obj.transcribe(audio_path, beam_size=5)
    text = " ".join([s.text for s in segments])

    return timestamp, text

def transcribe_and_save(audio_path, model="small"):
    """
    Transcribe audio and save to daily note with timestamp.
    Uses the obsidian skill for vault integration.

    Args:
        audio_path: Path to audio file
        model: Model size

    Returns:
        Tuple of (note_path, timestamp, transcribed_text)
    """
    timestamp, text = transcribe_with_timestamp(audio_path, model)
    note_path = append_to_daily_note(text, timestamp=timestamp)
    return note_path, timestamp, text

def generate_speech(text, output_file="output.wav", model_path=None):
    """
    Generate speech from text using Piper.

    Args:
        text: Text to speak
        output_file: Output audio file path
        model_path: Path to Piper model (defaults to en_US-lessac-medium)

    Returns:
        Path to generated audio file
    """
    model = model_path or PIPER_MODEL

    # Use piper via subprocess
    piper_bin = f"{VOICE_VENV}/bin/piper"

    proc = subprocess.run(
        [piper_bin, "--model", model, "--output_file", output_file],
        input=text.encode(),
        capture_output=True
    )

    if proc.returncode != 0:
        raise RuntimeError(f"Piper failed: {proc.stderr.decode()}")

    return output_file

def speak(text, output_file="/tmp/nazar_speech.wav"):
    """Quick TTS with default settings."""
    return generate_speech(text, output_file)

def convert_to_opus(wav_path, opus_path=None):
    """
    Convert WAV to OGG/Opus for WhatsApp voice messages.

    Args:
        wav_path: Path to WAV file
        opus_path: Output path (defaults to same name with .ogg)

    Returns:
        Path to OGG file
    """
    import av
    import numpy as np

    if opus_path is None:
        opus_path = wav_path.replace('.wav', '.ogg')

    # Open input
    container = av.open(wav_path, mode='r')
    audio_stream = container.streams.audio[0]

    # Resample to 48000Hz (WhatsApp standard)
    resampler = av.audio.resampler.AudioResampler(
        format='s16',
        layout='mono',
        rate=48000
    )

    # Open output
    output = av.open(opus_path, 'w')
    output_stream = output.add_stream('libopus', 48000)
    output_stream.bit_rate = 24000

    for packet in container.demux(audio_stream):
        for frame in packet.decode():
            frame.pts = None
            resampled_frames = resampler.resample(frame)
            for resampled_frame in resampled_frames:
                for packet in output_stream.encode(resampled_frame):
                    output.mux(packet)

    # Flush
    for packet in output_stream.encode():
        output.mux(packet)

    output.close()
    container.close()

    return opus_path
