#!/bin/bash
#
# Syncthing Setup for Nazar
# Run this after bootstrap to configure Syncthing for vault sync
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

NAZAR_HOME="/home/nazar"
VAULT_DIR="$NAZAR_HOME/vault"

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

log_info "Setting up Syncthing for nazar user..."

# Ensure directories exist
mkdir -p "$VAULT_DIR"
chown -R nazar:nazar "$NAZAR_HOME"

# Enable and start Syncthing user service
log_info "Starting Syncthing service..."
su - nazar -c "systemctl --user enable syncthing"
su - nazar -c "systemctl --user start syncthing"

# Wait for Syncthing to initialize
sleep 3

# Get Syncthing config
CONFIG_DIR="$NAZAR_HOME/.local/state/syncthing"
if [ -f "$CONFIG_DIR/config.xml" ]; then
    DEVICE_ID=$(su - nazar -c "syncthing cli show system | grep -o '\"myID\": \"[^\"]*\"' | cut -d'\"' -f4")
    log_success "Syncthing Device ID: $DEVICE_ID"
else
    log_warn "Syncthing config not yet created. Will be available after first start."
fi

# Get Tailscale IP for GUI access
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "not connected")

log_success "Syncthing setup complete!"
echo ""
echo "To complete setup:"
echo ""
echo "1. Access Syncthing GUI:"
echo "   http://$TAILSCALE_IP:8384"
echo ""
echo "2. Set GUI username/password in Settings -> GUI"
echo ""
echo "3. On your other devices (laptop, phone):"
echo "   - Install Syncthing"
echo "   - Add this VPS as a device (ID shown above)"
echo "   - Share your vault folder with this device"
echo ""
echo "4. On this VPS, accept the device and folder in the GUI"
echo "   OR use CLI:"
echo "   sudo -u nazar syncthing cli show pending-devices"
echo "   sudo -u nazar syncthing cli config devices add --device-id <ID>"
echo ""
echo "Recommended Syncthing settings for vault:"
echo "  - Folder path: /home/nazar/vault"
echo "  - Folder ID: nazar-vault"
echo "  - Versioning: Simple File Versioning (keep 3)"
echo "  - Ignore permissions: OFF (respect Linux permissions)"
echo ""
