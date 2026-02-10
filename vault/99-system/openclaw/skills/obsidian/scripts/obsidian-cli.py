#!/usr/bin/env python3
"""CLI for Obsidian vault operations."""

import sys
import os
import argparse
from datetime import datetime

# Add the skill directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from obsidian import (
    get_vault_config,
    get_daily_note_path,
    create_daily_note,
    append_to_daily_note,
    create_note,
    read_note,
    note_exists,
    list_daily_notes
)

def main():
    parser = argparse.ArgumentParser(description='Obsidian Vault CLI')
    subparsers = parser.add_subparsers(dest='command', help='Commands')

    # Config command
    subparsers.add_parser('config', help='Show vault configuration')

    # Daily note path command
    path_parser = subparsers.add_parser('daily-path', help='Get daily note path')
    path_parser.add_argument('--date', help='Date in YYYY-MM-DD format (default: today)')

    # Create daily note command
    create_parser = subparsers.add_parser('create-daily', help='Create daily note')
    create_parser.add_argument('--content', '-c', required=True, help='Note content')
    create_parser.add_argument('--date', help='Date in YYYY-MM-DD format (default: today)')

    # Append to daily note command
    append_parser = subparsers.add_parser('append', help='Append to daily note')
    append_parser.add_argument('--content', '-c', required=True, help='Content to append')
    append_parser.add_argument('--date', help='Date in YYYY-MM-DD format (default: today)')
    append_parser.add_argument('--time', help='Timestamp (default: current time)')

    # Create note command
    note_parser = subparsers.add_parser('create', help='Create a new note')
    note_parser.add_argument('title', help='Note title')
    note_parser.add_argument('--content', '-c', default='', help='Note content')
    note_parser.add_argument('--folder', '-f', help='Target folder (default: 00-inbox)')

    # Read note command
    read_parser = subparsers.add_parser('read', help='Read a note')
    read_parser.add_argument('path', help='Note path (relative to vault)')

    # List daily notes command
    list_parser = subparsers.add_parser('list-daily', help='List daily notes')
    list_parser.add_argument('--year', help='Filter by year')
    list_parser.add_argument('--month', help='Filter by month (1-12)')

    args = parser.parse_args()

    if args.command == 'config':
        config = get_vault_config()
        print("=== Vault Configuration ===")
        print(f"Daily notes folder: {config.get('daily_notes', {}).get('folder', 'N/A')}")
        print(f"New file location: {config.get('app', {}).get('newFileFolderPath', 'N/A')}")
        print(f"Attachments: {config.get('app', {}).get('attachmentFolderPath', 'N/A')}")

        plugins = config.get('core_plugins', {})
        enabled = [k for k, v in plugins.items() if v]
        print(f"\nEnabled plugins: {', '.join(enabled[:5])}...")

    elif args.command == 'daily-path':
        if args.date:
            date = datetime.strptime(args.date, '%Y-%m-%d')
        else:
            date = None
        print(get_daily_note_path(date))

    elif args.command == 'create-daily':
        if args.date:
            date = datetime.strptime(args.date, '%Y-%m-%d')
        else:
            date = None
        path = create_daily_note(args.content, date)
        print(f"Created: {path}")

    elif args.command == 'append':
        if args.date:
            date = datetime.strptime(args.date, '%Y-%m-%d')
        else:
            date = None
        path = append_to_daily_note(args.content, date, args.time)
        print(f"Appended to: {path}")

    elif args.command == 'create':
        path = create_note(args.title, args.content, args.folder)
        print(f"Created: {path}")

    elif args.command == 'read':
        content = read_note(args.path)
        if content:
            print(content)
        else:
            print(f"Note not found: {args.path}", file=sys.stderr)
            sys.exit(1)

    elif args.command == 'list-daily':
        notes = list_daily_notes(args.year, args.month)
        for note in notes:
            print(note)

    else:
        parser.print_help()

if __name__ == '__main__':
    main()
