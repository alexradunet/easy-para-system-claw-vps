# Documentation Index

Welcome to the Nazar Second Brain documentation.

## Getting Started

| Document | Description |
|----------|-------------|
| [../README.md](../README.md) | Project overview and quick start |
| [../docker/VPS-GUIDE.md](../docker/VPS-GUIDE.md) | OVHcloud Debian 13 VPS deployment guide |
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
| [../docker/SECURITY.md](../docker/SECURITY.md) | Security hardening guide |
| [../docker/MIGRATION.md](../docker/MIGRATION.md) | Migration from old setup |
| [troubleshooting.md](troubleshooting.md) | Common issues and fixes |

## Reference

| Document | Description |
|----------|-------------|
| [skills.md](skills.md) | Available agent skills |

## Quick Reference

### Services

```bash
# Start/stop/restart
cd ~/nazar/docker
docker compose {up -d|down|restart}

# Or use CLI
nazar-cli {start|stop|restart}
```

### Access Points

| Service | URL (with SSH tunnel) |
|---------|----------------------|
| OpenClaw Gateway | `http://localhost:18789` |
| Syncthing GUI | `http://localhost:8384` |

**SSH Tunnel:**
```bash
ssh -N -L 18789:localhost:18789 -L 8384:localhost:8384 debian@vps-ip
```

### Important Paths

| Path | Purpose |
|------|---------|
| `~/nazar/vault/` | Obsidian vault |
| `~/nazar/.openclaw/` | OpenClaw configuration |
| `~/nazar/syncthing/config/` | Syncthing data |

### Infrastructure CLI

```bash
nazar-cli status       # Service status
nazar-cli logs         # View logs
nazar-cli restart      # Restart services
nazar-cli backup       # Create backup
nazar-cli tunnel       # Show SSH tunnel command
nazar-cli security     # Run security audit
```
