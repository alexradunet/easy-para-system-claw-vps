# Docker Deployment

Run Nazar as a Docker container on your VPS.

## Architecture

One container with Git-based vault sync:

1. **nazar-gateway** — OpenClaw + voice tools, vault at `/vault`
2. **vault.git** — Bare Git repo served over SSH for vault synchronization

Defined in `deploy/docker-compose.yml`.

## Quick Start

```bash
# 1. Push deploy/ repo to VPS
scp -r deploy/ user@vps:/srv/nazar/deploy/

# 2. Run setup
ssh user@vps
sudo bash /srv/nazar/deploy/scripts/setup-vps.sh

# 3. Run setup wizard
openclaw configure

# 4. Restart (if needed)
cd /srv/nazar && docker compose up -d
```

## What's in the Image

The custom `Dockerfile.nazar` extends the official OpenClaw build with:

- **node:22-bookworm** base
- **OpenClaw** built from source (pnpm)
- **Python 3 + venv** with voice tools:
  - faster-whisper (STT)
  - piper-tts (TTS)
  - pydub, av (audio processing)
- **Pre-downloaded models:**
  - Whisper `small` model
  - Piper `en_US-lessac-medium` voice
- **System tools:** ffmpeg, ripgrep, jq, git

## Directory Layout on VPS

```
/srv/nazar/
├── docker-compose.yml
├── .env                  ← Secrets (never committed)
├── vault/                ← Obsidian vault (git working copy)
│   ├── 00-inbox/
│   ├── 01-daily-journey/
│   ├── ...
│   └── 99-system/
├── vault.git/            ← Bare Git repo (push/pull target)
└── data/
    └── openclaw/         ← OpenClaw config + state
```

## Ports

| Port | Service | Binding |
|------|---------|---------|
| 443 (HTTPS) | OpenClaw Gateway | loopback -> Tailscale Serve |
| 22 (SSH) | Git vault sync | `tailscale0` only |

## Management

```bash
cd /srv/nazar

# View status
docker compose ps

# View logs
docker compose logs -f
docker compose logs -f nazar-gateway

# Restart
docker compose restart

# Rebuild (after updating Dockerfile)
docker compose build --no-cache nazar-gateway
docker compose up -d

# Stop
docker compose down
```

## Updating

```bash
# Update deploy repo
cd /srv/nazar/deploy && git pull

# Re-run setup (safe to re-run)
sudo bash scripts/setup-vps.sh
```

## Troubleshooting

### Permission issues
```bash
chown -R 1000:1000 /srv/nazar/vault /srv/nazar/data
```

### High memory usage
Add resource limits to docker-compose.yml:
```yaml
deploy:
  resources:
    limits:
      memory: 2G
```

---

See [Setup Guide](setup.md) for first-time installation.
