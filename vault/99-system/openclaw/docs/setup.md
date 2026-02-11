# Setup Guide

Complete setup instructions for Nazar — your Obsidian-based AI agent.

## Prerequisites

- OVH VPS (or any Debian server) with Docker installed
- Tailscale for secure access
- Obsidian vault synced via Git
- API keys for your chosen LLM provider(s)

## Deployment (Docker on VPS)

### 1. Push deploy repo to VPS

```bash
# From your local machine
scp -r deploy/ user@vps:/srv/nazar/deploy/
```

### 2. Run VPS setup script

```bash
ssh user@vps
cd /srv/nazar/deploy
sudo bash scripts/setup-vps.sh
```

This will:
- Create `/srv/nazar/{vault,data/openclaw}`
- Clone OpenClaw source to `/opt/openclaw`
- Overlay the custom Dockerfile
- Copy compose + config files
- Generate a gateway token
- Build and start containers

### 3. Run setup wizard

```bash
openclaw configure
```

This sets up models, API keys, and channels (WhatsApp) interactively.

### 4. Clone vault on your devices

```bash
git clone debian@<tailscale-ip>:/srv/nazar/vault.git ~/vault
```

### 5. Verify

```bash
cd /srv/nazar
docker compose ps                    # Container healthy
curl -sk https://<tailscale-hostname>/  # Gateway responds
docker compose exec nazar-gateway ls /vault/  # Vault visible
```

## Local Development

For testing skills locally without Docker:

```bash
# Set environment variables
export VAULT_PATH=/path/to/your/vault
export VOICE_VENV=/path/to/voice-venv
export WHISPER_MODEL_DIR=/path/to/models/whisper
export PIPER_MODEL_DIR=/path/to/models/piper

# Test obsidian CLI
python3 vault/99-system/openclaw/skills/obsidian/scripts/obsidian-cli.py config

# Test voice CLI
python3 vault/99-system/openclaw/skills/voice/scripts/voice-cli.py --help
```

## Troubleshooting

### Gateway not responding

```bash
docker compose logs nazar-gateway
docker compose restart nazar-gateway
```

### Voice models missing

Models are baked into the Docker image at build time. Rebuild if needed:
```bash
docker compose build --no-cache nazar-gateway
```

### Permission issues

Ensure `/srv/nazar/vault` is owned by uid 1000:
```bash
chown -R 1000:1000 /srv/nazar/vault
```

---

See [Usage Guide](usage.md) for day-to-day operations.
