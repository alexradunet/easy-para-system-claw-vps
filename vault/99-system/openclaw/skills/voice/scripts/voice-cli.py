#!/usr/bin/env python3
"""CLI for voice processing (STT and TTS)."""

import sys
import os
import argparse

# Add skill directories to path (relative to vault)
VAULT_PATH = os.environ.get("VAULT_PATH", "/vault")
sys.path.insert(0, os.path.join(VAULT_PATH, "99-system/openclaw/skills/voice"))
sys.path.insert(0, os.path.join(VAULT_PATH, "99-system/openclaw/skills/obsidian"))

from voice import (
    transcribe_audio,
    transcribe_with_timestamp,
    transcribe_and_save,
    generate_speech,
    speak,
    convert_to_opus
)

def main():
    parser = argparse.ArgumentParser(description='Voice Processing CLI')
    subparsers = parser.add_subparsers(dest='command', help='Commands')

    # Transcribe command
    transcribe_parser = subparsers.add_parser('transcribe', help='Transcribe audio to text')
    transcribe_parser.add_argument('audio', help='Path to audio file')
    transcribe_parser.add_argument('--model', '-m', default='small',
                                  choices=['tiny', 'base', 'small', 'medium', 'large'],
                                  help='Whisper model size (default: small)')
    transcribe_parser.add_argument('--save', '-s', action='store_true',
                                  help='Save to daily note with timestamp')

    # Speak command
    speak_parser = subparsers.add_parser('speak', help='Generate speech from text')
    speak_parser.add_argument('text', help='Text to speak (or use --file)')
    speak_parser.add_argument('--file', '-f', help='Read text from file')
    speak_parser.add_argument('--output', '-o', default='/tmp/voice_output.wav',
                              help='Output file path (default: /tmp/voice_output.wav)')
    speak_parser.add_argument('--opus', action='store_true',
                              help='Convert to OGG/Opus for WhatsApp')

    # Daily voice note command
    daily_parser = subparsers.add_parser('daily-note', help='Transcribe and save to daily note')
    daily_parser.add_argument('audio', help='Path to audio file')
    daily_parser.add_argument('--model', '-m', default='small',
                             choices=['tiny', 'base', 'small', 'medium', 'large'])

    args = parser.parse_args()

    if args.command == 'transcribe':
        print(f"Transcribing with {args.model} model...", file=sys.stderr)

        if args.save:
            path, timestamp, text = transcribe_and_save(args.audio, args.model)
            print(f"Saved to: {path}")
            print(f"Timestamp: [{timestamp}]")
            print(f"\nTranscription:\n{text}")
        else:
            text = transcribe_audio(args.audio, args.model)
            print(text)

    elif args.command == 'speak':
        if args.file:
            with open(args.file, 'r') as f:
                text = f.read()
        else:
            text = args.text

        print(f"Generating speech...", file=sys.stderr)
        wav_path = speak(text, args.output)
        print(f"WAV: {wav_path}")

        if args.opus:
            opus_path = convert_to_opus(wav_path)
            print(f"Opus: {opus_path}")

    elif args.command == 'daily-note':
        print(f"Transcribing and saving to daily note...", file=sys.stderr)
        path, timestamp, text = transcribe_and_save(args.audio, args.model)
        print(f"Saved to: {path}")
        print(f"Timestamp: [{timestamp}]")
        print(f"\nTranscription:\n{text}")

    else:
        parser.print_help()

if __name__ == '__main__':
    main()
