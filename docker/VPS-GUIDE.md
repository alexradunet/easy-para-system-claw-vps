# OVHcloud Debian 13 VPS Deployment Guide

Complete guide for deploying the Nazar Second Brain infrastructure on an OVHcloud VPS running Debian 13.

## Overview

Deploy OpenClaw + Syncthing with:

- **Single user**: `debian` (admin) - no separate service user needed
- **Docker isolation**: All services run in containers
- **SSH tunnel access**: Secure access without exposing ports
- **Persistent state**: Vault and configs survive container restarts
- **~€3.50–5.50/month**: OVHcloud VPS Starter or Value tier

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        OVHcloud VPS                              │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    Docker Engine                        │    │
│  │                                                         │    │
│  │  ┌──────────────┐      ┌──────────────┐                │    │
│  │  │   OpenClaw   │◄────►│  Syncthing   │                │    │
│  │  │   Gateway    │      │    Sync      │                │    │
│  │  │  Container   │      │  Container   │                │    │
│  │  └──────┬───────┘      └──────┬───────┘                │    │
│  │         │                     │                        │    │
│  │         └──────────┬──────────┘                        │    │
│  │                    │                                   │    │
│  │         ┌──────────┴──────────┐                        │    │
│  │         │   ~/nazar/vault     │                        │    │
│  │         │   (bind mount)      │                        │    │
│  │         └─────────────────────┘                        │    │
│  │                                                         │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  SSH Access: ssh -L 18789:localhost:18789 debian@<vps-ip>       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │     Laptop      │
                    │  Obsidian +     │
                    │  Syncthing      │
                    └─────────────────┘
```

## OVHcloud VPS Plans

| Plan | Specs | Monthly Cost |
| ----------- | --------------- | ------------ |
| VPS Starter | 1 vCPU, 2GB RAM | ~€3.50 |
| VPS Value | 2 vCPU, 4GB RAM | ~€5.50 |

Both tiers are sufficient. VPS Starter works fine for a single user.

## Step 1: Order OVHcloud VPS

1. Go to [OVHcloud Control Panel](https://ca.ovh.com/manager/)
2. **Order VPS**:
   - **Range**: VPS Starter or VPS Value
   - **Location**: Closest to you
   - **OS**: Debian 13
   - **Options**: Enable automated backup (~20% of VPS price, recommended)
3. **Note your VPS IP** from the control panel after provisioning

### OVHcloud KVM Console

OVHcloud provides a KVM (keyboard/video/mouse) console in the control panel. This is your emergency fallback if you lock yourself out of SSH. Find it under your VPS → **KVM** tab.

## Step 2: Initial Server Setup

Connect as root and create the `debian` user:

```bash
# SSH into the VPS as root
ssh root@YOUR_VPS_IP

# Create debian user
adduser debian
usermod -aG sudo debian

# Set up SSH keys for debian user
mkdir -p /home/debian/.ssh
cp /root/.ssh/authorized_keys /home/debian/.ssh/
chown -R debian:debian /home/debian/.ssh
chmod 700 /home/debian/.ssh
chmod 600 /home/debian/.ssh/authorized_keys

# Optional but recommended: Run security hardening
curl -fsSL https://raw.githubusercontent.com/alexradunet/easy-para-system-claw-vps/master/docker/setup-security.sh | bash

# Switch to debian user
su - debian
```

## Step 3: Install Docker

```bash
# Update and install dependencies
sudo apt-get update
sudo apt-get install -y git curl ca-certificates

# Install Docker
curl -fsSL https://get.docker.com | sh

# Add debian user to docker group
sudo usermod -aG docker debian

# Verify
logout
ssh debian@YOUR_VPS_IP
docker --version
docker compose version
```

## Step 4: Deploy Infrastructure

### Option A: Quick Deploy (Recommended)

```bash
# Download and run setup script
curl -fsSL https://raw.githubusercontent.com/alexradunet/easy-para-system-claw-vps/master/docker/setup.sh | bash

# Follow the prompts for:
# - Deployment mode (SSH tunnel or Tailscale)
# - Security hardening (recommended: yes)
```

### Option B: Manual Deploy

```bash
# Create directory structure
mkdir -p ~/nazar/docker
mkdir -p ~/nazar/vault
mkdir -p ~/nazar/.openclaw/workspace
mkdir -p ~/nazar/syncthing/config

# Download Docker files
cd ~/nazar/docker
curl -fsSL https://raw.githubusercontent.com/alexradunet/easy-para-system-claw-vps/master/docker/docker-compose.yml -o docker-compose.yml
curl -fsSL https://raw.githubusercontent.com/alexradunet/easy-para-system-claw-vps/master/docker/Dockerfile.openclaw -o Dockerfile.openclaw
curl -fsSL https://raw.githubusercontent.com/alexradunet/easy-para-system-claw-vps/master/docker/.env.example -o .env

# Create .env
cat > .env << 'EOF'
DEPLOYMENT_MODE=sshtunnel
VAULT_HOST_PATH=/home/debian/nazar/vault
OPENCLAW_CONFIG_PATH=/home/debian/nazar/.openclaw
OPENCLAW_WORKSPACE_PATH=/home/debian/nazar/.openclaw/workspace
SYNCTHING_CONFIG_PATH=/home/debian/nazar/syncthing/config
OPENCLAW_GATEWAY_BIND=127.0.0.1
OPENCLAW_GATEWAY_PORT=18789
CONTAINER_UID=1000
CONTAINER_GID=1000
EOF

# Generate token and create config
mkdir -p ~/nazar/.openclaw/workspace
TOKEN=$(openssl rand -hex 32)

cat > ~/nazar/.openclaw/openclaw.json << EOF
{
  "name": "nazar",
  "workspace": { "path": "/home/node/.openclaw/workspace" },
  "sandbox": { "mode": "non-main" },
  "gateway": {
    "enabled": true,
    "bind": "0.0.0.0",
    "port": 18789,
    "auth": { "type": "token", "token": "$TOKEN" }
  },
  "models": {},
  "channels": {},
  "tools": {
    "allowed": ["read_file", "write_file", "edit_file", "shell", "web_search", "task"],
    "sandbox": { "binds": ["/vault:/vault:rw"] }
  },
  "limits": { "maxConcurrentAgents": 4, "maxConcurrentSubagents": 8 }
}
EOF

# Fix permissions
chown -R 1000:1000 ~/nazar

# Build and start
docker compose up -d --build
```

## Step 5: Access Services

### Open SSH Tunnel (on your laptop)

```bash
# Both services at once
ssh -N -L 18789:localhost:18789 -L 8384:localhost:8384 debian@YOUR_VPS_IP

# Background mode
ssh -f -N -L 18789:localhost:18789 -L 8384:localhost:8384 debian@YOUR_VPS_IP
```

### Access Services

| Service | URL (with tunnel) |
| ---------------- | ---------------------- |
| OpenClaw Gateway | http://localhost:18789 |
| Syncthing GUI | http://localhost:8384 |

## Step 6: Post-Infrastructure Setup

Once the infrastructure is running, you need to configure the services:

1. **Configure Syncthing** — Add your devices, share the vault folder (`~/nazar/vault` on VPS, `/var/syncthing/vault` in container)
2. **Configure OpenClaw** — Run the onboarding wizard: `docker compose exec -it openclaw openclaw configure`

These are separate from infrastructure provisioning and are handled through each service's own UI/CLI.

## Security Hardening

The automated security script implements OVHcloud best practices:

```bash
# Run security hardening
curl -fsSL https://raw.githubusercontent.com/alexradunet/easy-para-system-claw-vps/master/docker/setup-security.sh | sudo bash

# Or run audit only
sudo nazar-security-audit
```

Features:

- SSH key authentication only
- UFW firewall (blocks all incoming except SSH)
- Fail2ban (blocks IPs after 3 failed attempts)
- Automatic security updates

See [SECURITY.md](SECURITY.md) for details.

## OVHcloud Network Firewall

OVHcloud provides an additional network-level firewall in the control panel:

1. Go to **Network** → **Firewall**
2. Enable firewall for your VPS
3. Create rules:
   - Allow TCP 22 (SSH)
   - Deny all other incoming

This provides defense in depth with UFW on the VPS itself.

## OVHcloud Backup Option

OVHcloud offers automated backup:

- Enable in control panel
- ~20% of VPS price
- One-click restore

### Automated Script Backup

```bash
# Create backup script
cat > ~/nazar/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="$HOME/nazar/backups"
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

cd ~/nazar/docker
docker compose stop

tar -czf "$BACKUP_DIR/nazar-$TIMESTAMP.tar.gz" \
    -C ~/nazar \
    vault .openclaw syncthing

docker compose up -d

# Keep only last 7 backups
ls -t "$BACKUP_DIR"/nazar-*.tar.gz | tail -n +8 | xargs -r rm

echo "Backup: $BACKUP_DIR/nazar-$TIMESTAMP.tar.gz"
EOF

chmod +x ~/nazar/backup.sh

# Daily at 3 AM
(crontab -l 2>/dev/null; echo "0 3 * * * /home/debian/nazar/backup.sh") | crontab -
```

## Management Commands

### Using nazar-cli

```bash
# Install
sudo ln -s ~/nazar/docker/nazar-cli.sh /usr/local/bin/nazar-cli

# Usage
nazar-cli status      # Show service status
nazar-cli logs        # Show all logs
nazar-cli restart     # Restart services
nazar-cli backup      # Create backup
nazar-cli token       # Show gateway token
nazar-cli tunnel      # Show SSH tunnel command
nazar-cli security    # Run security audit
```

### Docker Compose Directly

```bash
cd ~/nazar/docker

# Start
docker compose up -d

# View logs
docker compose logs -f

# Stop
docker compose down

# Update
docker compose pull
docker compose up -d --build
```

## Troubleshooting

### Services Won't Start

```bash
# Check logs
docker compose logs

# Check disk space
df -h

# Fix permissions
chown -R 1000:1000 ~/nazar
```

### Can't Access Gateway

```bash
# Verify tunnel is active on laptop
ssh -N -L 18789:localhost:18789 debian@YOUR_VPS_IP

# Check OpenClaw logs
docker compose logs openclaw
```

### Syncthing Not Syncing

```bash
# Check connections
docker compose exec syncthing syncthing cli show connections

# Restart Syncthing
docker compose restart syncthing
```

### Out of Memory

If hitting OOM on 2GB VPS:

```bash
# Add swap
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Or upgrade to VPS Value tier in OVHcloud control panel
```

### Locked Out of SSH

Use the OVHcloud KVM console (control panel → your VPS → KVM) to regain access and fix SSH configuration.

## Resources

- [OVHcloud VPS Documentation](https://docs.ovh.com/gb/en/vps/)
- [OVHcloud: How to secure a VPS](https://docs.ovh.com/gb/en/vps/tips-for-securing-a-vps/)
- [OpenClaw Documentation](https://github.com/openclaw/openclaw)
- [Syncthing Documentation](https://docs.syncthing.net/)
- [Project Repository](https://github.com/alexradunet/easy-para-system-claw-vps)

---

_For issues or contributions, see the main project repository._
