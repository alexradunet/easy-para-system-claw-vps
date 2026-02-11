# Troubleshooting

Common issues and their solutions.

## Quick Diagnostics

Run this to check everything:

```bash
#!/bin/bash
echo "=== Tailscale ==="
tailscale status 2>/dev/null || echo "Tailscale not running"

echo ""
echo "=== Services ==="
sudo -u nazar systemctl --user is-active openclaw 2>/dev/null && echo "✓ OpenClaw" || echo "✗ OpenClaw"
sudo -u nazar systemctl --user is-active syncthing 2>/dev/null && echo "✓ Syncthing" || echo "✗ Syncthing"

echo ""
echo "=== Firewall ==="
sudo ufw status | head -5

echo ""
echo "=== Disk Space ==="
df -h /home/nazar | tail -1

echo ""
echo "=== Memory ==="
free -h | grep Mem
```

## Syncthing Issues

### Devices Not Connecting

**Symptom**: Devices show as "Disconnected" in Syncthing GUI

**Check**:
```bash
# 1. Tailscale connectivity
tailscale status
ping <other-device-tailscale-ip>

# 2. Syncthing is running
sudo -u nazar systemctl --user status syncthing

# 3. Device IDs are correct
sudo -u nazar syncthing cli show system | grep myID
```

**Fix**:
- Ensure Tailscale is running on both devices
- Re-add device IDs if changed
- Check firewall: `sudo ufw status`

### Sync Conflicts

**Symptom**: Files like `note.md.sync-conflict-20260211-143022.md`

**Fix**:
1. Open both files in Obsidian
2. Compare and merge changes manually
3. Delete the `.sync-conflict-*` file

**Prevent**:
- Enable "Auto Save" in Obsidian
- Avoid editing the same file simultaneously on multiple devices

### Slow Sync

**Check**:
```bash
# Connection type (relay vs direct)
sudo -u nazar syncthing cli show connections | grep type

# Should show "type": "tcp-client" or "type": "tcp-server"
# "type": "relay-client" means using relay (slower)
```

**Fix**:
- Ensure both devices on same Tailscale network
- Check "Allow Direct Connections" in device settings

## OpenClaw Issues

### Gateway Won't Start

**Symptom**: `systemctl --user status openclaw` shows failed

**Check**:
```bash
# Logs
sudo -u nazar journalctl --user -u openclaw -n 50

# Config validity
sudo -u nazar jq . ~/.openclaw/openclaw.json

# Port in use
sudo ss -tlnp | grep 18789
```

**Common Fixes**:

1. **Invalid JSON config**:
   ```bash
   # Backup and reset
   sudo -u nazar cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak
   sudo -u nazar openclaw configure
   ```

2. **Port already in use**:
   ```bash
   # Find and kill process
   sudo ss -tlnp | grep 18789
   sudo kill <PID>
   # Then restart
   sudo -u nazar systemctl --user restart openclaw
   ```

3. **Missing dependencies**:
   ```bash
   # Reinstall OpenClaw
   sudo npm install -g openclaw@latest
   ```

### Can't Access Web UI

**Symptom**: `https://<tailscale-hostname>/` doesn't load

**Check**:
```bash
# 1. Gateway is running
sudo -u nazar systemctl --user status openclaw

# 2. Listening on localhost
sudo -u nazar ss -tlnp | grep 18789
# Should show 127.0.0.1:18789

# 3. Tailscale serve is working
tailscale serve status

# 4. Tailscale is connected
tailscale status
```

**Fix**:
```bash
# Restart Tailscale serve
sudo tailscale serve --https=443 off 2>/dev/null || true
sudo -u nazar systemctl --user restart openclaw

# Check Tailscale HTTPS
tailscale cert <hostname>.<tailnet>.ts.net
```

### Device Pairing Issues

**Symptom**: "Pairing required" message in browser

**Fix**:
```bash
# List pending devices
sudo -u nazar openclaw devices list

# Approve
sudo -u nazar openclaw devices approve <request-id>

# Restart gateway
sudo -u nazar systemctl --user restart openclaw
```

### Voice Processing Not Working

**Symptom**: Voice messages not transcribed

**Check**:
```bash
# Voice venv exists
ls -la /home/nazar/.local/venv-voice/

# Whisper and Piper installed
sudo -u nazar bash -c 'source ~/.local/venv-voice/bin/activate && which whisper'
sudo -u nazar bash -c 'source ~/.local/venv-voice/bin/activate && which piper'

# Models exist
ls /home/nazar/.local/share/whisper/
```

**Fix**:
```bash
# Reinstall voice tools
sudo -u nazar bash -c '
    python3 -m venv ~/.local/venv-voice
    source ~/.local/venv-voice/bin/activate
    pip install openai-whisper piper-tts
'
```

## Tailscale Issues

### Can't SSH via Tailscale

**Symptom**: `ssh debian@<tailscale-ip>` hangs or fails

**Check**:
```bash
# Tailscale status
tailscale status

# IP is correct
tailscale ip -4

# Firewall allows SSH on tailscale0
sudo ufw status | grep tailscale0
```

**Fix**:
```bash
# Restart Tailscale
sudo systemctl restart tailscaled

# Re-authenticate if needed
sudo tailscale up --force-reauth

# If locked out, use provider console to access and fix
```

### Tailscale Not Connecting

**Symptom**: `tailscale status` shows "Logged out"

**Fix**:
```bash
# Authenticate
sudo tailscale up

# Or if already configured
sudo tailscale up --operator=debian
```

## Permission Issues

### Vault Not Writable

**Symptom**: OpenClaw can't write to vault

**Fix**:
```bash
sudo chown -R nazar:nazar /home/nazar/vault
chmod -R u+rw /home/nazar/vault
```

### Can't Access OpenClaw Config

**Fix**:
```bash
sudo chown -R nazar:nazar /home/nazar/.openclaw
chmod -R u+rw /home/nazar/.openclaw
```

## System Issues

### Out of Disk Space

**Check**:
```bash
df -h /home/nazar
du -sh /home/nazar/vault/*
```

**Fix**:
```bash
# Clean old Syncthing versions
sudo -u nazar find /home/nazar/vault -name "*.sync-conflict-*" -delete

# Check Syncthing versioning settings
# Reduce "Keep Versions" in folder settings
```

### High Memory Usage

**Check**:
```bash
free -h
ps aux --sort=-%mem | head -10
```

**Common causes**:
- Whisper model too large (use `small` or `base`)
- Syncthing scanning large files
- OpenClaw subagent memory leak

**Fix**:
```bash
# Restart services
sudo -u nazar systemctl --user restart openclaw
sudo -u nazar systemctl --user restart syncthing

# Use smaller Whisper model (edit voice skill config)
```

### System Won't Boot

**If you can't access the VPS:**
1. Use provider's web console (KVM/VNC)
2. Check disk space from recovery mode
3. Check logs: `journalctl -xb`

**Common boot issues**:
- Full disk (clean up from recovery)
- Failed systemd service (mask it: `systemctl mask <service>`)

## Getting Help

If none of these solutions work:

1. **Check logs**:
   ```bash
   # OpenClaw
   sudo -u nazar journalctl --user -u openclaw -n 100
   
   # Syncthing
   sudo -u nazar journalctl --user -u syncthing -n 100
   
   # System
   sudo journalctl -n 100
   ```

2. **Check OpenClaw documentation**:
   ```bash
   openclaw --help
   openclaw doctor
   ```

3. **Restart everything** (nuclear option):
   ```bash
   sudo systemctl restart tailscaled
   sudo -u nazar systemctl --user restart syncthing
   sudo -u nazar systemctl --user restart openclaw
   ```
