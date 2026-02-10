# Usage Guide

Day-to-day usage of Nazar.

## Communication Channels

### WhatsApp (Primary)
- Send text messages
- Send voice messages (auto-transcribed to daily notes)
- Receive voice replies
- Get notifications

### Web Chat
- Access via OpenClaw web interface
- Good for desktop use
- Copy-paste friendly

## Core Workflows

### Voice to Journal

**Simple:** Send a voice message → Nazar transcribes it and saves to today's daily note with a timestamp.

**Result in daily note (`01-daily-journey/YYYY/MM-MMMM/YYYY-MM-DD.md`):**
```markdown
---

**[14:32]**

Just had a great meeting with the team, we decided to...
```

### Daily Note Creation

Daily notes are created automatically in:
```
01-daily-journey/2026/02-February/2026-02-10.md
```

You can also ask:
- "Create today's daily note"
- "What did I write on Monday?"
- "List my daily notes from January"

### Vault Queries

Ask about your vault:
- "What's in my 02-projects folder?"
- "List my active projects"
- "Search for mentions of 'meeting' in my notes"

### Quick Captures

- **Ideas**: "Add to inbox: idea for new app"
- **Tasks**: "Remind me to call mom tomorrow"
- **Thoughts**: Voice message anytime

## CLI Tools

### Obsidian CLI

```bash
# Show vault config
python3 /vault/99-system/openclaw/skills/obsidian/scripts/obsidian-cli.py config

# Get today's note path
python3 /vault/99-system/openclaw/skills/obsidian/scripts/obsidian-cli.py daily-path

# Create a note
python3 /vault/99-system/openclaw/skills/obsidian/scripts/obsidian-cli.py create "Project Idea" \
  --content "# New Idea\n\nDetails here..." \
  --folder "02-projects"

# Read a note
python3 /vault/99-system/openclaw/skills/obsidian/scripts/obsidian-cli.py read \
  "01-daily-journey/2026/02-February/2026-02-10.md"
```

### Voice CLI

```bash
# Transcribe audio file
python3 /vault/99-system/openclaw/skills/voice/scripts/voice-cli.py transcribe audio.ogg

# Transcribe and save to daily note
python3 /vault/99-system/openclaw/skills/voice/scripts/voice-cli.py transcribe audio.ogg --save

# Generate speech
python3 /vault/99-system/openclaw/skills/voice/scripts/voice-cli.py speak "Hello world"

# Generate WhatsApp voice message
python3 /vault/99-system/openclaw/skills/voice/scripts/voice-cli.py speak "Your message here" --opus
```

## Customizing Nazar

### Edit Personality

Edit `99-system/openclaw/workspace/SOUL.md`:
- How formal/casual to be
- Sense of humor
- What Nazar values
- How to make decisions

### Teach About You

Edit `99-system/openclaw/workspace/USER.md`:
- Your name, preferences
- Your goals and projects
- What annoys you

### Add Periodic Checks

Edit `99-system/openclaw/workspace/HEARTBEAT.md`:
```markdown
# Daily Checks
- [ ] Check email for urgent messages
- [ ] Review calendar for tomorrow
- [ ] Check weather if going out
```

---

Questions? Check the other docs or just ask Nazar!
