# Documentation Index

Welcome to the Nazar Second Brain documentation.

## Getting Started

| Document | Description |
|----------|-------------|
| [../README.md](../README.md) | Project overview and quick start |
| [../README-BOOTSTRAP.md](../README-BOOTSTRAP.md) | VPS bootstrap guide |
| [syncthing-setup.md](syncthing-setup.md) | Configure vault sync |
| [openclaw-config.md](openclaw-config.md) | Configure AI gateway |

## Understanding the System

| Document | Description |
|----------|-------------|
| [architecture.md](architecture.md) | System design and data flow |
| [vault-structure.md](vault-structure.md) | PARA method and folder conventions |
| [agent.md](agent.md) | Nazar agent system |

## Administration

| Document | Description |
|----------|-------------|
| [../system/docs/admin-guide.md](../system/docs/admin-guide.md) | System administration |
| [troubleshooting.md](troubleshooting.md) | Common issues and fixes |
| [migration-from-docker.md](migration-from-docker.md) | Migrate from old Docker setup |

## Reference

| Document | Description |
|----------|-------------|
| [skills.md](skills.md) | Available agent skills |

## Quick Reference

### Services

```bash
# Start/stop/restart
sudo -u nazar systemctl --user {start|stop|restart} openclaw
sudo -u nazar systemctl --user {start|stop|restart} syncthing

# Status
nazar-status

# Logs
nazar-logs                    # OpenClaw
sudo -u nazar journalctl --user -u syncthing -f  # Syncthing
```

### Access Points

| Service | URL |
|---------|-----|
| OpenClaw Gateway | `https://<tailscale-hostname>/` |
| Syncthing GUI | `http://<tailscale-ip>:8384` |
| SSH | `ssh debian@<tailscale-ip>` |

### Important Paths

| Path | Purpose |
|------|---------|
| `/home/nazar/vault/` | Obsidian vault |
| `/home/nazar/.openclaw/` | OpenClaw configuration |
| `/home/nazar/.local/state/syncthing/` | Syncthing data |

### CLI Commands

```bash
# OpenClaw
sudo -u nazar openclaw configure
sudo -u nazar openclaw devices list
sudo -u nazar openclaw devices approve <id>

# Syncthing
sudo -u nazar syncthing cli show system
sudo -u nazar syncthing cli show connections
sudo -u nazar syncthing cli show folders
```
