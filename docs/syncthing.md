# Syncthing Setup

Syncthing keeps your Obsidian vault synchronized across all devices via peer-to-peer encrypted transfer. No cloud service involved.

## How It Works

```
Laptop (Obsidian)  ◄──── Syncthing P2P ────►  VPS (Docker)
       ▲                                              ▲
       │                                              │
       └──────── Syncthing P2P ────►  Phone (Obsidian)
```

Each device runs Syncthing. When any device changes a file, all other devices get the update within seconds (or minutes, depending on network).

## Architecture in This Stack

Syncthing runs as a Docker container (`nazar-syncthing`) on the VPS:

| Path (container) | Path (host) | Purpose |
|-------------------|-------------|---------|
| `/var/syncthing/vault` | `/srv/nazar/vault` | The vault folder being synced |
| `/var/syncthing/config` | `/srv/nazar/data/syncthing` | Syncthing config + keys |

The OpenClaw container also bind-mounts `/srv/nazar/vault` at `/vault`, so both containers share the same files.

## Initial Setup

### 1. Access Syncthing UI on VPS

Via Tailscale:
```
http://<tailscale-ip>:8384
```

On first access, Syncthing will ask you to set a UI password. Do it.

### 2. Get the VPS Device ID

In the Syncthing UI → Actions → Show ID. Copy the full device ID string.

### 3. Add VPS as a device on your laptop

On your laptop's Syncthing:
1. Add Remote Device
2. Paste the VPS device ID
3. Give it a name (e.g., "Nazar VPS")
4. Save

### 4. Share the vault folder

On your laptop's Syncthing:
1. Add Folder (or edit existing vault folder)
2. Folder Path: your local vault path (e.g., `C:\Second_Brain\vault\`)
3. Sharing tab → check "Nazar VPS"
4. Save

### 5. Accept the share on VPS

The VPS Syncthing UI will show a prompt to accept the shared folder:
- Folder Label: `vault`
- Folder Path: `/var/syncthing/vault` (this maps to `/srv/nazar/vault` on the host)
- Accept

### 6. Wait for sync

Initial sync may take a while depending on vault size. Monitor progress in the Syncthing UI.

## Phone Setup

### Android
- Install [Syncthing](https://play.google.com/store/apps/details?id=com.nutomic.syncthingandroid) from Play Store
- Add the VPS device (paste Device ID)
- Share the vault folder
- Point Obsidian to the synced folder

### iOS
- Use [Möbius Sync](https://apps.apple.com/app/mobius-sync/id1539203216) (Syncthing client for iOS)
- Or use Obsidian Sync (paid) alongside Syncthing on VPS

## Conflict Resolution

Syncthing handles most conflicts automatically. When it can't:

- Conflicting files get renamed: `filename.sync-conflict-20260211-143052-ABCDEFG.md`
- Check for `.sync-conflict-*` files periodically
- Resolve by keeping the version you want and deleting the conflict file

To check for conflicts:
```bash
find /srv/nazar/vault -name "*.sync-conflict-*"
```

## Ignore Patterns

Create `.stignore` in the vault root to exclude files from sync:

```
// Obsidian workspace state (device-specific)
.obsidian/workspace.json
.obsidian/workspace-mobile.json

// Python cache
__pycache__
*.pyc

// OS files
.DS_Store
Thumbs.db

// Temporary files
*.tmp
*.swp
```

To add this on the VPS:
```bash
cat > /srv/nazar/vault/.stignore << 'EOF'
.obsidian/workspace.json
.obsidian/workspace-mobile.json
__pycache__
*.pyc
.DS_Store
Thumbs.db
*.tmp
*.swp
EOF
```

## Syncthing Ports

| Port | Protocol | Purpose | Must be open? |
|------|----------|---------|---------------|
| 8384 | TCP | Web UI | No (127.0.0.1, Tailscale) |
| 22000 | TCP | Block transfer | Yes (public) |
| 22000 | UDP | QUIC transfer | Yes (public) |
| 21027 | UDP | Local + global discovery | Yes (public) |

## Monitoring

### Check sync status
```bash
# Via Syncthing API
curl -s -H "X-API-Key: $(grep apikey /srv/nazar/data/syncthing/config.xml | sed 's/.*>\(.*\)<.*/\1/')" \
  http://127.0.0.1:8384/rest/db/status?folder=default | python3 -m json.tool
```

### Check for out-of-sync files
```bash
docker compose logs nazar-syncthing | grep -i "conflict\|error" | tail -20
```

## Troubleshooting

### Devices not connecting
- Verify ports 22000 and 21027 are open: `sudo ufw status`
- Check Syncthing logs: `docker compose logs nazar-syncthing`
- Ensure both devices show as "Connected" in UI

### Slow sync
- QUIC (UDP 22000) is faster than TCP — ensure UDP is open
- Check if relay is being used (slower) — direct connections are preferred
- Large binary files (images, PDFs) take longer

### Permission issues after sync
```bash
sudo chown -R 1000:1000 /srv/nazar/vault
```
