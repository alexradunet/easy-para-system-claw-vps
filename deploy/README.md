# Nazar Deploy

Docker deployment stack for the Nazar AI assistant (OpenClaw gateway + Git-based vault sync).

## Architecture

One container, Git-based vault sync:

- **nazar-gateway** — OpenClaw with voice tools (Whisper STT + Piper TTS)
- **vault.git** — Bare Git repo served over SSH for vault synchronization

The gateway bind-mounts the vault working copy. Vault sync uses Git over SSH (through Tailscale) — no extra containers or public ports. A cron job auto-commits agent writes every 5 minutes.

## Quick Start

```bash
# On your VPS
git clone <this-repo> /srv/nazar/deploy
cd /srv/nazar/deploy
sudo bash scripts/setup-vps.sh

# Edit secrets
nano /srv/nazar/.env

# Restart with secrets
cd /srv/nazar && docker compose restart

# Clone vault on your laptop
git clone nazar@<tailscale-ip>:/srv/nazar/vault.git ~/vault
```

## Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Gateway container definition |
| `Dockerfile.nazar` | OpenClaw + voice tools image |
| `openclaw.json` | Agent config (multi-model, sandbox) |
| `.env.example` | Secrets template |
| `scripts/setup-vps.sh` | VPS bootstrap script (creates vault group, git repos, cron, starts container) |
| `scripts/vault-post-receive-hook` | Git hook template (auto-deploys to working copy on push) |
| `scripts/vault-auto-commit.sh` | Cron script template (commits agent writes every 5 min) |
| `scripts/vault-gitignore` | .gitignore template for the vault |

## Ports

| Port | Service | Access |
|------|---------|--------|
| 443 (HTTPS) | OpenClaw Gateway | `https://<tailscale-hostname>/` (automatic via integrated Tailscale Serve) |
| 22 (SSH) | Git vault sync | `git clone nazar@<tailscale-ip>:/srv/nazar/vault.git` (Tailscale only) |

No public ports needed. All access flows through Tailscale.

## Management

```bash
cd /srv/nazar
docker compose ps          # Status
docker compose logs -f     # Logs
docker compose restart     # Restart
docker compose down        # Stop
docker compose build       # Rebuild
tail -f data/git-sync.log  # Vault sync log
```
