# Syncthing Setup Guide

Syncthing provides real-time synchronization of your Obsidian vault across all devices.

## Architecture

```
┌─────────────┐      Tailscale      ┌─────────────┐      Tailscale      ┌─────────────┐
│   Laptop    │ ◄─────── VPN ───────► │     VPS     │ ◄─────── VPN ───────► │    Phone    │
│  Syncthing  │                       │  Syncthing  │                       │  Syncthing  │
│  ~/vault    │ ◄─── sync vault ────► │ ~/vault     │ ◄─── sync vault ────► │  ~/vault    │
└─────────────┘                       └─────────────┘                       └─────────────┘
```

## Initial Setup

### On the VPS (Nazar)

After running the bootstrap script:

```bash
# Start Syncthing
sudo bash nazar/scripts/setup-syncthing.sh

# Get your device ID
sudo -u nazar syncthing cli show system | grep myID
```

Access the GUI:
```
http://<vps-tailscale-ip>:8384
```

**First-time GUI setup:**
1. Set admin username and password (important!)
2. Note the Device ID (Settings → General → Device ID)
3. Keep the GUI accessible only on Tailscale interface

### On Your Laptop

1. **Install Syncthing:**
   - macOS: `brew install syncthing`
   - Windows: Download from syncthing.net
   - Linux: `apt install syncthing`

2. **Start Syncthing:**
   ```bash
   syncthing serve
   ```

3. **Access GUI:** `http://localhost:8384`

4. **Add VPS as Device:**
   - Actions → Show ID (copy your laptop's device ID)
   - Add Remote Device → Enter VPS device ID
   - Sharing: Check "Introducer" to auto-share folders

### On Your Phone

1. **Install Syncthing:**
   - Android: F-Droid or Play Store
   - iOS: Möbius Sync (paid) or use alternative

2. **Add VPS Device:**
   - Use QR code scan or enter Device ID manually
   - Accept on VPS side

## Folder Configuration

### On VPS (as nazar user)

```bash
# Create vault folder if not exists
mkdir -p /home/nazar/vault

# Via GUI or CLI - add folder
sudo -u nazar syncthing cli config folders add --id nazar-vault --label "Nazar Vault" --path /home/nazar/vault

# Share with your devices
sudo -u nazar syncthing cli config folders nazar-vault devices add --device-id <LAPTOP-DEVICE-ID>
sudo -u nazar syncthing cli config folders nazar-vault devices add --device-id <PHONE-DEVICE-ID>
```

### Recommended Settings

**Folder Settings (`nazar-vault`):**

| Setting | Value | Reason |
|---------|-------|--------|
| Folder Path | `/home/nazar/vault` | Central location |
| Folder ID | `nazar-vault` | Unique identifier |
| File Versioning | Simple File Versioning | Protect against accidental deletes |
| Keep Versions | 3 | Balance safety vs storage |
| Cleanup Interval | 3600 (1 hour) | Regular cleanup |
| Ignore Permissions | OFF | Respect Linux permissions |

**Device Settings:**

| Setting | Value |
|---------|-------|
| Auto Accept | Enabled (for known folders) |
| Compression | Metadata (default) |
| Rate Limiting | Unlimited on LAN, limit on WAN if needed |

## Security

### Bind to Tailscale Only

Edit `/home/nazar/.local/state/syncthing/config.xml`:

```xml
<gui enabled="true" tls="false">
    <address>100.x.x.x:8384</address>  <!-- Your Tailscale IP -->
    <user>admin</user>
    <password>$2a$10$...</password>  <!-- bcrypt hash -->
</gui>
```

Or via environment variable in the systemd service:
```
Environment="STGUIADDRESS=100.x.x.x:8384"
```

### Firewall

Syncthing ports are only needed if you want direct connections (not through Tailscale relays):

```bash
# Optional: Allow Syncthing discovery
sudo ufw allow in on tailscale0 to any port 22000 proto tcp comment 'Syncthing'
sudo ufw allow in on tailscale0 to any port 22000 proto udp comment 'Syncthing'
sudo ufw allow in on tailscale0 to any port 21027 proto udp comment 'Syncthing discovery'
```

## Troubleshooting

### Devices Not Connecting

1. Check Tailscale is running on both sides:
   ```bash
   tailscale status
   ```

2. Verify Syncthing is listening:
   ```bash
   sudo -u nazar ss -tlnp | grep syncthing
   ```

3. Check device IDs are correct

### Sync Conflicts

Syncthing creates conflict files: `filename.sync-conflict-YYYYMMDD-HHMMSS.md`

To resolve:
1. Compare versions in Obsidian
2. Merge manually
3. Delete conflict file

### Permission Issues

Ensure proper ownership:
```bash
sudo chown -R nazar:nazar /home/nazar/vault
```

### Logs

```bash
# Syncthing logs
sudo -u nazar journalctl --user -u syncthing -f

# Syncthing CLI
sudo -u nazar syncthing cli show system
sudo -u nazar syncthing cli show connections
sudo -u nazar syncthing cli show folders
```

## CLI Reference

```bash
# As nazar user
sudo -u nazar syncthing [command]

# Common commands
syncthing cli show system           # System info
syncthing cli show config           # Full config
syncthing cli show connections      # Connected devices
syncthing cli show folders          # Folder status
syncthing cli show pending-devices  # Devices waiting to connect
syncthing cli show pending-folders  # Folders waiting to sync

# Add device
syncthing cli config devices add --device-id <ID> --name "My Laptop"

# Add folder
syncthing cli config folders add --id vault --path /home/nazar/vault

# Restart
systemctl --user restart syncthing
```
