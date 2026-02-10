# Skills Development

Creating new capabilities for Nazar.

## What is a Skill?

A skill is a self-contained module that adds functionality. Skills live in `99-system/openclaw/skills/` and are auto-discovered.

## Anatomy of a Skill

```
skills/your-skill/
├── SKILL.md              # Documentation and metadata
├── your_skill.py         # Python module (optional)
└── scripts/              # CLI tools (optional)
    └── your-cli.py
```

## Creating a Skill

### 1. Create the Folder

```bash
mkdir -p /vault/99-system/openclaw/skills/my-skill/scripts
```

### 2. Write SKILL.md

```markdown
---
name: my-skill
description: What this skill does and when to use it.
---

# My Skill

## Purpose
Brief explanation of what this skill does.

## Usage

### Python API
\```python
from my_skill import do_something
result = do_something("input")
\```

### CLI
\```bash
python3 skills/my-skill/scripts/cli.py --help
\```

## Requirements
- List any dependencies
- Any setup needed
```

### 3. Write the Python Module

Use environment variables for paths — never hardcode:

```python
"""My skill functionality."""
import os

VAULT_PATH = os.environ.get("VAULT_PATH", "/vault")

def do_something(input_data):
    """Do something with the input."""
    return processed_data
```

### 4. Integration with Obsidian

Skills can read/write to your vault via the obsidian skill:

```python
import sys, os
VAULT_PATH = os.environ.get("VAULT_PATH", "/vault")
sys.path.insert(0, os.path.join(VAULT_PATH, "99-system/openclaw/skills/obsidian"))
from obsidian import append_to_daily_note, create_note

# Add weather to daily note
append_to_daily_note(f"## Weather\n\n{weather}")

# Create a dedicated note
create_note("Weather Log", f"# Weather\n\n{weather}")
```

## Best Practices

1. **Self-contained** — Each skill should work independently
2. **Documented** — Always include SKILL.md
3. **Portable** — Use env vars for paths, never hardcode
4. **Error handling** — Gracefully handle failures
5. **Vault-aware** — Use obsidian skill for vault operations

---

Build what you need. Make it yours.
