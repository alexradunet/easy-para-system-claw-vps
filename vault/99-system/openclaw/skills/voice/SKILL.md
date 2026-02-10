---
name: voice
description: Local voice processing using Whisper (STT) and Piper (TTS). Transcribe audio files to text, generate speech, and save voice notes to Obsidian Daily Journey with timestamps.
---

# Voice Processing Skill

Local voice processing without cloud APIs. Now with automatic timestamp tracking for Obsidian daily notes.

## Capabilities

- **Speech-to-Text (STT)**: Transcribe audio files using Whisper
- **Text-to-Speech (TTS)**: Generate voice audio using Piper
- **Daily Note Integration**: Save voice notes to Obsidian with timestamps

## Requirements

All paths are configured via environment variables with sensible defaults:

- Virtual environment: `$VOICE_VENV` (default: `/opt/voice-venv`)
- Whisper models: `$WHISPER_MODEL_DIR` (default: `/opt/models/whisper`)
- Piper voices: `$PIPER_MODEL_DIR` (default: `/opt/models/piper`)
- Obsidian vault: `$VAULT_PATH` (default: `/vault`)

## Usage

### Transcribe Audio

```bash
python3 /vault/99-system/openclaw/skills/voice/scripts/transcribe.py <audio_file> [model_size]
```

Models: tiny, base, small (default), medium, large

### Generate Speech

```bash
echo "Your text here" | piper \
  --model $PIPER_MODEL_DIR/en_US-lessac-medium.onnx \
  --output_file output.wav
```

### Save Voice Note to Daily Journal

```python
import sys, os
sys.path.insert(0, os.path.join(os.environ.get('VAULT_PATH', '/vault'), '99-system/openclaw/skills/voice'))
from voice import transcribe_and_save

# Transcribes and saves with timestamp
note_path, timestamp, text = transcribe_and_save("audio.ogg")
print(f"Saved to {note_path} at [{timestamp}]")
```

## Python API

```python
from voice import (
    transcribe_audio,           # Basic transcription
    transcribe_with_timestamp,  # Get (timestamp, text)
    append_to_daily_note,       # Save to daily note
    transcribe_and_save,        # Full pipeline
    generate_speech,            # TTS
    speak                       # Quick TTS
)

# Basic STT
text = transcribe_audio("audio.mp3", model="small")

# With timestamp
timestamp, text = transcribe_with_timestamp("audio.ogg")
# Returns: ("20:47", "transcribed text here...")

# Save to daily note (auto-timestamped)
append_to_daily_note("Your note here")
# Appends: ---\n\n**[20:47]**\n\nYour note here

# Full pipeline: transcribe + save
note_path, timestamp, text = transcribe_and_save("audio.ogg")
```

## Daily Note Format

Voice notes are appended to `01-daily-journey/YYYY/MM-MMMM/YYYY-MM-DD.md` with timestamps:

```markdown
---

**[20:47]**

Your transcribed voice note here...

---

**[21:15]**

Another voice note...
```
