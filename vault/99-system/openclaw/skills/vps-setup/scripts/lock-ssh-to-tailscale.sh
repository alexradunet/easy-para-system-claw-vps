#!/bin/bash
# lock-ssh-to-tailscale.sh — Remove public SSH access, allow only via Tailscale
# Run ONLY after confirming you can SSH via Tailscale IP.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

[[ $EUID -eq 0 ]] || error "Run as root: sudo bash $0"

# Check Tailscale is running
if ! tailscale status &>/dev/null; then
    error "Tailscale is not running. Install and start it first."
fi

TS_IP=$(tailscale ip -4 2>/dev/null)
if [ -z "$TS_IP" ]; then
    error "Could not get Tailscale IP. Is Tailscale authenticated?"
fi

echo ""
warn "This will remove public SSH access (port 22)."
warn "SSH will ONLY work via Tailscale IP: $TS_IP"
warn ""
warn "Before proceeding, confirm you can SSH via Tailscale:"
warn "  ssh debian@$TS_IP"
echo ""
read -p "Have you confirmed Tailscale SSH works? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted. Confirm Tailscale SSH works first."
    exit 0
fi

info "Locking SSH to Tailscale interface..."

# Remove public SSH rule
ufw delete allow 22/tcp 2>/dev/null || true

# Allow SSH only on Tailscale interface
ufw allow in on tailscale0 to any port 22 comment "SSH-via-Tailscale"
ufw reload

info "SSH is now Tailscale-only."
echo ""
echo "Tailscale IP: $TS_IP"
echo "SSH command:  ssh debian@$TS_IP"
echo ""
echo "Emergency access: Use the OVHcloud KVM console (control panel → your VPS → KVM)"
echo "To undo: sudo ufw allow 22/tcp && sudo ufw delete allow in on tailscale0 to any port 22"
