# OpenClaw Configuration

OpenClaw is the AI framework that powers the Nazar agent. This guide covers configuration for the non-Docker setup.

## Configuration Location

| File | Purpose |
|------|---------|
| `/home/nazar/.openclaw/openclaw.json` | Main configuration |
| `/home/nazar/.openclaw/devices/paired.json` | Approved devices |
| `/home/nazar/.openclaw/devices/pending.json` | Pending device approvals |

## Initial Configuration

After installation, run the setup wizard:

```bash
sudo -u nazar openclaw configure
```

This interactive wizard will guide you through:
1. **Model selection** (Claude, GPT-4, etc.)
2. **API key entry** (encrypted storage)
3. **Channel setup** (WhatsApp, Telegram, Web)

## Manual Configuration

### openclaw.json Structure

```json
{
  "name": "nazar",
  "workspace": {
    "path": "/home/nazar/vault/99-system/openclaw/workspace"
  },
  "sandbox": {
    "mode": "non-main"
  },
  "gateway": {
    "enabled": true,
    "bind": "loopback",
    "port": 18789,
    "auth": {
      "type": "token",
      "token": "your-secure-token-here"
    },
    "tailscale": {
      "mode": "serve"
    }
  },
  "models": {
    "default": {
      "provider": "anthropic",
      "model": "claude-sonnet-4-20250514",
      "apiKey": "${ANTHROPIC_API_KEY}"
    }
  },
  "channels": {
    "whatsapp": {
      "enabled": true,
      "...": "..."
    }
  },
  "tools": {
    "allowed": ["read_file", "write_file", "edit_file", "shell", "web_search"],
    "sandbox": {
      "binds": ["/home/nazar/vault:/vault:rw"]
    }
  }
}
```

### Environment Variables

You can use environment variables in the config:

```json
{
  "models": {
    "default": {
      "apiKey": "${ANTHROPIC_API_KEY}"
    }
  }
}
```

Set in `/home/nazar/.openclaw/.env`:
```bash
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
```

## Service Management

### Start/Stop/Restart

```bash
# As debian user with sudo
sudo -u nazar systemctl --user start openclaw
sudo -u nazar systemctl --user stop openclaw
sudo -u nazar systemctl --user restart openclaw

# Or use helper alias (as debian)
nazar-restart
```

### Check Status

```bash
# Service status
sudo -u nazar systemctl --user status openclaw

# View logs
sudo -u nazar journalctl --user -u openclaw -f

# Or use helper
nazar-logs
```

### Enable/Disable Auto-start

```bash
# Enable (starts on boot)
sudo -u nazar systemctl --user enable openclaw

# Disable
sudo -u nazar systemctl --user disable openclaw
```

## Device Pairing

The first time you access the web UI from a new browser, you need to approve the device.

### List Pending Devices

```bash
sudo -u nazar openclaw devices list
```

### Approve a Device

```bash
sudo -u nazar openclaw devices approve <request-id>
```

### Manual Approval (via files)

```bash
# View pending
sudo -u nazar cat ~/.openclaw/devices/pending.json

# Copy to paired
sudo -u nazar cp ~/.openclaw/devices/pending.json ~/.openclaw/devices/paired.json

# Restart gateway
sudo -u nazar systemctl --user restart openclaw
```

## Access URLs

| URL | Description |
|-----|-------------|
| `https://<tailscale-hostname>/` | Main gateway (web UI) |
| `http://localhost:18789/` | Local access (on VPS) |

## Troubleshooting

### Gateway Won't Start

Check logs:
```bash
sudo -u nazar journalctl --user -u openclaw -n 50
```

Common issues:
- **Port already in use**: Check `sudo ss -tlnp | grep 18789`
- **Missing config**: Verify `~/.openclaw/openclaw.json` exists
- **Invalid JSON**: Validate with `jq . ~/.openclaw/openclaw.json`

### Can't Access Web UI

1. Check Tailscale is running:
   ```bash
   tailscale status
   ```

2. Verify gateway is listening:
   ```bash
   sudo -u nazar ss -tlnp | grep 18789
   ```

3. Check Tailscale serve status:
   ```bash
   tailscale serve status
   ```

### Voice Processing Not Working

Ensure the voice venv is set up:
```bash
sudo -u nazar bash -c '
    source ~/.local/venv-voice/bin/activate
    which whisper
    which piper
'
```

### Reset Configuration

```bash
# Backup first
sudo -u nazar cp -r ~/.openclaw ~/.openclaw.bak.$(date +%Y%m%d)

# Reset
sudo -u nazar rm -rf ~/.openclaw
sudo -u nazar mkdir -p ~/.openclaw

# Re-run setup
sudo -u nazar openclaw configure
```

## CLI Reference

```bash
# Configuration
openclaw configure              # Interactive setup wizard
openclaw doctor                 # Health check
openclaw doctor --fix           # Auto-fix issues

# Devices
openclaw devices list           # List connected/pending devices
openclaw devices approve <id>   # Approve pending device

# Gateway
openclaw gateway status         # Gateway status
openclaw gateway logs           # Gateway logs

# Help
openclaw --help
openclaw <command> --help
```
