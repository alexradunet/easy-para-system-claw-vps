"""Obsidian vault utilities for file operations and structure awareness."""

import os
import json
from datetime import datetime
from pathlib import Path

VAULT_PATH = os.environ.get("VAULT_PATH", "/vault")
CONFIG_PATH = f"{VAULT_PATH}/.obsidian"

def get_vault_config():
    """Load Obsidian configuration files."""
    config = {}

    # App config
    app_config_path = f"{CONFIG_PATH}/app.json"
    if os.path.exists(app_config_path):
        with open(app_config_path, 'r') as f:
            config['app'] = json.load(f)

    # Daily notes config
    daily_config_path = f"{CONFIG_PATH}/daily-notes.json"
    if os.path.exists(daily_config_path):
        with open(daily_config_path, 'r') as f:
            config['daily_notes'] = json.load(f)

    # Core plugins
    plugins_path = f"{CONFIG_PATH}/core-plugins.json"
    if os.path.exists(plugins_path):
        with open(plugins_path, 'r') as f:
            config['core_plugins'] = json.load(f)

    return config

def get_daily_note_path(date=None):
    """
    Get the file path for a daily note.

    Args:
        date: datetime object (defaults to today)

    Returns:
        Full path to the daily note file
    """
    if date is None:
        date = datetime.now()

    config = get_vault_config()
    daily_config = config.get('daily_notes', {})

    folder = daily_config.get('folder', '01-daily-journey/').rstrip('/')

    # Format: YYYY/MM-MMMM/YYYY-MM-DD
    year = date.strftime('%Y')
    month_folder = date.strftime('%m-%B')  # e.g., 02-February
    filename = date.strftime('%Y-%m-%d') + '.md'

    return f"{VAULT_PATH}/{folder}/{year}/{month_folder}/{filename}"

def ensure_folder(path):
    """Create folder if it doesn't exist."""
    os.makedirs(os.path.dirname(path), exist_ok=True)

def create_daily_note(content, date=None, template=None):
    """
    Create or overwrite a daily note.

    Args:
        content: Markdown content for the note
        date: datetime object (defaults to today)
        template: Optional template content to prepend

    Returns:
        Path to the created file
    """
    note_path = get_daily_note_path(date)
    ensure_folder(note_path)

    full_content = content
    if template:
        full_content = template + "\n\n" + content

    with open(note_path, 'w', encoding='utf-8') as f:
        f.write(full_content)

    return note_path

def append_to_daily_note(content, date=None, timestamp=None):
    """
    Append content to a daily note.

    Args:
        content: Content to append
        date: datetime object (defaults to today)
        timestamp: Optional timestamp string (defaults to current time)

    Returns:
        Path to the updated file
    """
    note_path = get_daily_note_path(date)
    ensure_folder(note_path)

    if timestamp is None:
        timestamp = datetime.now().strftime('%H:%M')

    # Format entry with timestamp
    entry = f"\n\n---\n\n**[{timestamp}]**\n\n{content}"

    with open(note_path, 'a', encoding='utf-8') as f:
        f.write(entry)

    return note_path

def create_note(title, content, folder=None, frontmatter=None):
    """
    Create a new note in the vault.

    Args:
        title: Note title (used as filename)
        content: Markdown content
        folder: Target folder (defaults to 00-inbox/)
        frontmatter: Optional dict for YAML frontmatter

    Returns:
        Path to the created file
    """
    config = get_vault_config()
    app_config = config.get('app', {})

    if folder is None:
        folder = app_config.get('newFileFolderPath', '00-inbox/')

    # Sanitize filename
    safe_title = "".join(c for c in title if c.isalnum() or c in (' ', '-', '_')).rstrip()
    safe_title = safe_title.replace(' ', '-')

    note_path = f"{VAULT_PATH}/{folder.rstrip('/')}/{safe_title}.md"
    ensure_folder(note_path)

    # Build content with frontmatter
    full_content = ""
    if frontmatter:
        full_content += "---\n"
        for key, value in frontmatter.items():
            if isinstance(value, list):
                full_content += f"{key}: {value}\n"
            else:
                full_content += f"{key}: {value}\n"
        full_content += "---\n\n"

    full_content += content

    with open(note_path, 'w', encoding='utf-8') as f:
        f.write(full_content)

    return note_path

def read_note(path):
    """Read a note from the vault."""
    full_path = path if path.startswith(VAULT_PATH) else f"{VAULT_PATH}/{path}"

    if not os.path.exists(full_path):
        return None

    with open(full_path, 'r', encoding='utf-8') as f:
        return f.read()

def note_exists(path):
    """Check if a note exists."""
    full_path = path if path.startswith(VAULT_PATH) else f"{VAULT_PATH}/{path}"
    return os.path.exists(full_path)

def get_attachment_path(filename, note_path=None):
    """
    Get path for an attachment.

    Args:
        filename: Name of the attachment
        note_path: Path of the referencing note (for relative paths)

    Returns:
        Full path for the attachment
    """
    config = get_vault_config()
    app_config = config.get('app', {})

    attachment_folder = app_config.get('attachmentFolderPath', './attachments')

    if attachment_folder.startswith('./') and note_path:
        # Relative to note location
        note_dir = os.path.dirname(note_path)
        relative_folder = attachment_folder.replace('./', '')
        return f"{note_dir}/{relative_folder}/{filename}"
    else:
        # Absolute from vault root
        return f"{VAULT_PATH}/{attachment_folder}/{filename}"

def list_daily_notes(year=None, month=None):
    """
    List daily notes, optionally filtered by year/month.

    Returns:
        List of note paths
    """
    config = get_vault_config()
    daily_config = config.get('daily_notes', {})
    folder = daily_config.get('folder', '01-daily-journey/').rstrip('/')

    base_path = f"{VAULT_PATH}/{folder}"
    notes = []

    if year and month:
        # Specific month
        month_name = datetime(int(year), int(month), 1).strftime('%m-%B')
        month_path = f"{base_path}/{year}/{month_name}"
        if os.path.exists(month_path):
            notes = [f"{month_path}/{f}" for f in os.listdir(month_path) if f.endswith('.md')]
    elif year:
        # All months in year
        year_path = f"{base_path}/{year}"
        if os.path.exists(year_path):
            for month_folder in os.listdir(year_path):
                month_path = f"{year_path}/{month_folder}"
                if os.path.isdir(month_path):
                    notes.extend([f"{month_path}/{f}" for f in os.listdir(month_path) if f.endswith('.md')])
    else:
        # All notes
        for root, dirs, files in os.walk(base_path):
            for file in files:
                if file.endswith('.md'):
                    notes.append(os.path.join(root, file))

    return sorted(notes)
