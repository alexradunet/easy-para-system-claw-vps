# System Administration Guide

This guide is for the `debian` user (system administrator) to manage the Nazar Second Brain system.

## User Responsibilities

| User | Role | Can Do |
|------|------|--------|
| `root` | Initial setup only | Bootstrap, then disable SSH |
| `debian` | System administrator | Update system, manage services, view logs |
| `nazar` | Service user | Run OpenClaw, Syncthing, access vault |

## Quick Reference

### Status Checks

```bash
# All services
nazar-status

# Individual services
sudo -u nazar systemctl --user status openclaw
sudo -u nazar systemctl --user status syncthing

# Tailscale
tailscale status
tailscale ip -4

# Disk space
df -h /home/nazar

# Memory
free -h
```

### Logs

```bash
# OpenClaw logs
nazar-logs
# or
sudo -u nazar journalctl --user -u openclaw -f

# Syncthing logs
sudo -u nazar journalctl --user -u syncthing -f

# System logs
sudo journalctl -f
```

### Service Management

```bash
# Restart OpenClaw
nazar-restart

# Restart Syncthing
sudo -u nazar systemctl --user restart syncthing

# Stop/start
sudo -u nazar systemctl --user stop openclaw
sudo -u nazar systemctl --user start openclaw
```

## Maintenance Tasks

### System Updates

```bash
# Update packages
sudo apt update && sudo apt upgrade -y

# Check for reboot required
[ -f /var/run/reboot-required ] && echo "Reboot required"
```

### Backup Vault

```bash
# Create backup
tar czf ~/vault-backup-$(date +%Y%m%d).tar.gz -C /home/nazar vault

# Or sync to external git
cd /home/nazar/vault
git init
git add -A
git commit -m "Backup $(date)"
git remote add backup git@github.com:youruser/vault-backup.git
git push -u backup main
```

### Check Security

```bash
# Review SSH logs
sudo journalctl -u sshd | tail -20

# Check fail2ban
sudo fail2ban-client status sshd

# Review firewall
sudo ufw status verbose

# Check for failed services
systemctl --failed
```

## Troubleshooting

### Syncthing Won't Start

```bash
# Check config
sudo -u nazar cat ~/.local/state/syncthing/config.xml | head -20

# Reset if corrupted (backup first!)
sudo -u nazar mv ~/.local/state/syncthing/config.xml ~/.local/state/syncthing/config.xml.bak
sudo -u nazar systemctl --user restart syncthing

# Reconfigure via GUI
```

### OpenClaw Won't Start

```bash
# Check config validity
sudo -u nazar jq . ~/.openclaw/openclaw.json

# Check Node.js
which node
node --version

# Check OpenClaw installation
which openclaw
openclaw --version

# Reinstall if needed
sudo npm install -g openclaw@latest
```

### Permission Issues

```bash
# Fix vault permissions
sudo chown -R nazar:nazar /home/nazar/vault

# Fix OpenClaw permissions
sudo chown -R nazar:nazar /home/nazar/.openclaw

# Fix Syncthing permissions
sudo chown -R nazar:nazar /home/nazar/.local/state/syncthing
```

### Tailscale Issues

```bash
# Restart Tailscale
sudo systemctl restart tailscaled

# Re-authenticate
sudo tailscale up --force-reauth

# Check status
tailscale status
tailscale netcheck
```

## Security Hardening

### Disable Root SSH (if not already done)

```bash
sudo cat /etc/ssh/sshd_config.d/nazar.conf | grep PermitRootLogin
# Should show: PermitRootLogin no
```

### Lock SSH to Tailscale Only

```bash
# First, verify Tailscale SSH works!
ssh debian@<tailscale-ip>

# Then lock down
sudo ufw delete allow 22/tcp
sudo ufw allow in on tailscale0 to any port 22 proto tcp comment 'SSH via Tailscale only'
sudo ufw reload
```

### Review User Access

```bash
# List users
cat /etc/passwd | grep -E "(debian|nazar)"

# Check sudo access
sudo -l -U debian
sudo -l -U nazar  # Should show nothing (no sudo)

# Check SSH authorized keys
sudo cat /home/debian/.ssh/authorized_keys
```

## Monitoring

### Set Up Log Rotation

Create `/etc/logrotate.d/nazar`:

```
/home/nazar/.openclaw/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 nazar nazar
}
```

### Simple Health Check Script

Create `~/bin/nazar-health-check`:

```bash
#!/bin/bash
echo "=== Nazar Health Check ==="
echo ""

echo "--- Services ---"
sudo -u nazar systemctl --user is-active openclaw && echo "✓ OpenClaw" || echo "✗ OpenClaw"
sudo -u nazar systemctl --user is-active syncthing && echo "✓ Syncthing" || echo "✗ Syncthing"

echo ""
echo "--- Tailscale ---"
tailscale status | head -3

echo ""
echo "--- Disk Space ---"
df -h /home/nazar | tail -1

echo ""
echo "--- Memory ---"
free -h | grep Mem
```

Make executable: `chmod +x ~/bin/nazar-health-check`

## Disaster Recovery

### If Nazar User Corrupted

```bash
# Backup current state
sudo tar czf /root/nazar-backup-$(date +%Y%m%d).tar.gz /home/nazar

# Recreate user
sudo userdel -r nazar
sudo useradd -m -s /bin/bash nazar

# Restore vault from Syncthing device
# (Syncthing will re-sync from other devices)
```

### If VPS Lost

1. Provision new VPS
2. Run bootstrap script
3. Install Syncthing
4. Add new VPS device to existing Syncthing nodes
5. Vault syncs automatically

## Useful Aliases

Add to `/home/debian/.bashrc`:

```bash
# Nazar management
alias nz-status='nazar-status'
alias nz-logs='nazar-logs'
alias nz-restart='nazar-restart'
alias nz-health='nazar-health-check'

# Quick navigation
alias nz-cd='cd /home/nazar'
alias nz-vault='cd /home/nazar/vault'

# Syncthing
alias nz-st='sudo -u nazar syncthing'
alias nz-st-status='sudo -u nazar systemctl --user status syncthing'
alias nz-st-logs='sudo -u nazar journalctl --user -u syncthing -f'

# OpenClaw
alias nz-oc='sudo -u nazar openclaw'
alias nz-oc-status='sudo -u nazar systemctl --user status openclaw'
alias nz-oc-logs='sudo -u nazar journalctl --user -u openclaw -f'
```
