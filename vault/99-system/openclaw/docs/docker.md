# Docker Deployment

Run Nazar as a two-container Docker stack on your VPS.

## Architecture

Two containers sharing one vault volume:

1. **nazar-gateway** — OpenClaw + voice tools, vault at `/vault`
2. **nazar-syncthing** — Syncthing, syncs vault with your devices

Both containers are defined in `deploy/docker-compose.yml`.

## Quick Start

```bash
# 1. Push deploy/ repo to VPS
scp -r deploy/ user@vps:/srv/nazar/deploy/

# 2. Run setup
ssh user@vps
sudo bash /srv/nazar/deploy/scripts/setup-vps.sh

# 3. Edit .env with API keys
nano /srv/nazar/.env

# 4. Restart
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
├── vault/                ← Obsidian vault (synced via Syncthing)
│   ├── 00-inbox/
│   ├── 01-daily-journey/
│   ├── ...
│   └── 99-system/
└── data/
    ├── openclaw/         ← OpenClaw config + state
    └── syncthing/        ← Syncthing config
```

## Ports

| Port | Service | Binding |
|------|---------|---------|
| 18789 | OpenClaw Gateway | 127.0.0.1 (Tailscale only) |
| 8384 | Syncthing UI | 127.0.0.1 (Tailscale only) |
| 22000/tcp | Syncthing sync | 0.0.0.0 |
| 22000/udp | Syncthing sync | 0.0.0.0 |
| 21027/udp | Syncthing discovery | 0.0.0.0 |

## Management

```bash
cd /srv/nazar

# View status
docker compose ps

# View logs
docker compose logs -f
docker compose logs -f nazar-gateway
docker compose logs -f nazar-syncthing

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

### Syncthing not syncing
Check firewall for ports 22000 and 21027.

---

See [Setup Guide](setup.md) for first-time installation.
