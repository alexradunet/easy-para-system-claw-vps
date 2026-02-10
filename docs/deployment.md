# Deployment Guide

How to go from a fresh Debian 13 VPS to a running Nazar instance.

## What Gets Deployed

Two Docker containers on the VPS:

1. **nazar-gateway** — OpenClaw + voice tools (Whisper, Piper), vault at `/vault`
2. **nazar-syncthing** — Syncthing, syncs vault with your devices

Both bind-mount the same vault directory at `/srv/nazar/vault/`.

## Prerequisites

- A Debian 13 VPS (OVH, Hetzner, or similar)
- Root SSH access (initial setup)
- A Tailscale account ([login.tailscale.com](https://login.tailscale.com))
- API keys for your LLM provider(s)

## Option A: Fully Automated (One Script)

### 1. Copy deploy repo to VPS

```bash
scp -r deploy/ root@<vps-ip>:/srv/nazar/deploy/
```

### 2. Run the master provisioning script

```bash
ssh root@<vps-ip>
bash /srv/nazar/deploy/../vault/99-system/openclaw/skills/vps-setup/scripts/provision-vps.sh \
  --deploy-repo /srv/nazar/deploy
```

This runs all phases:
- Creates `nazar` user with sudo + SSH keys
- Hardens SSH (key-only, no root)
- Configures firewall (UFW)
- Installs Fail2Ban + unattended upgrades
- Installs Tailscale (interactive auth step)
- Optionally locks SSH to Tailscale
- Installs Docker
- Builds and starts the containers
- Adds swap if low memory

### 3. Configure secrets

```bash
ssh nazar@<tailscale-ip>
nano /srv/nazar/.env
```

Fill in `ANTHROPIC_API_KEY`, `KIMI_API_KEY`, `WHATSAPP_NUMBER`.

### 4. Restart with secrets

```bash
cd /srv/nazar && docker compose restart
```

## Option B: Step by Step

### 1. Secure the VPS

```bash
ssh root@<vps-ip>
bash secure-vps.sh
```

### 2. Install Tailscale

```bash
bash install-tailscale.sh
# Open the auth URL in your browser
```

### 3. Lock SSH to Tailscale

```bash
# First verify: ssh nazar@<tailscale-ip>
bash lock-ssh-to-tailscale.sh
```

### 4. Install Docker

```bash
bash install-docker.sh
# Log out and back in for docker group
```

### 5. Deploy the stack

```bash
bash /srv/nazar/deploy/scripts/setup-vps.sh
```

### 6. Configure and start

```bash
nano /srv/nazar/.env
cd /srv/nazar && docker compose restart
```

## Option C: Claude Code Guided

SSH into the VPS, install Claude Code, then:

```
Read /srv/nazar/deploy/../vault/99-system/openclaw/skills/vps-setup/SKILL.md
and walk me through setting up this VPS
```

Claude Code will execute each phase interactively, pausing for confirmations.

## Directory Layout on VPS

```
/srv/nazar/                 ← Working directory
├── docker-compose.yml      ← Copied from deploy/
├── .env                    ← Secrets (auto-generated token + your API keys)
├── vault/                  ← Obsidian vault (synced via Syncthing)
│   ├── 00-inbox/
│   ├── 01-daily-journey/
│   ├── ...
│   └── 99-system/
└── data/
    ├── openclaw/           ← OpenClaw config + state
    │   └── openclaw.json
    └── syncthing/          ← Syncthing config

/opt/openclaw/              ← OpenClaw source (for Docker build)
├── Dockerfile.nazar        ← Custom Dockerfile (copied from deploy/)
└── ...                     ← Official OpenClaw source

/srv/nazar/deploy/          ← Deploy repo (reference copy)
```

## Docker Image Details

`Dockerfile.nazar` builds on `node:22-bookworm`:

- OpenClaw built from source (pnpm)
- Python 3 venv with: `faster-whisper`, `piper-tts`, `pydub`, `av`
- Pre-downloaded models: Whisper `small`, Piper `en_US-lessac-medium`
- System tools: `ffmpeg`, `ripgrep`, `jq`, `git`, `socat`

Build takes 10-15 minutes on a 2-core VPS. The image is ~3GB due to voice models.

## Ports

| Port | Service | Binding | Access |
|------|---------|---------|--------|
| 18789 | OpenClaw Gateway | `127.0.0.1` | Tailscale only |
| 8384 | Syncthing UI | `127.0.0.1` | Tailscale only |
| 22000/tcp | Syncthing sync | `0.0.0.0` | Public (needed for sync) |
| 22000/udp | Syncthing sync | `0.0.0.0` | Public (needed for sync) |
| 21027/udp | Syncthing discovery | `0.0.0.0` | Public (needed for discovery) |

## Management Commands

```bash
cd /srv/nazar

# Status
docker compose ps

# Logs
docker compose logs -f                    # All
docker compose logs -f nazar-gateway      # Gateway only
docker compose logs -f nazar-syncthing    # Syncthing only

# Restart
docker compose restart

# Rebuild (after updating Dockerfile)
docker compose build --no-cache nazar-gateway
docker compose up -d

# Stop
docker compose down

# Security audit
bash /srv/nazar/deploy/../vault/99-system/openclaw/skills/vps-setup/scripts/audit-vps.sh
```

## Updating

### Update deploy repo

```bash
cd /srv/nazar/deploy && git pull
```

### Re-run setup (safe to re-run)

```bash
sudo bash scripts/setup-vps.sh
```

### Rebuild image (after Dockerfile changes)

```bash
cd /srv/nazar
docker compose build --no-cache nazar-gateway
docker compose up -d
```

## Verification Checklist

```bash
docker compose ps                                    # Both running
curl -s http://127.0.0.1:18789                       # Gateway responds
curl -s http://127.0.0.1:8384                        # Syncthing UI loads
docker compose exec nazar-gateway ls /vault/          # Vault folders visible
docker compose exec nazar-gateway node -e "console.log('ok')"  # Node works
bash audit-vps.sh                                    # All checks pass
```
