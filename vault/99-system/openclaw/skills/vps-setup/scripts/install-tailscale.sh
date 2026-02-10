#!/bin/bash
# install-tailscale.sh — Install and authenticate Tailscale on Debian
# Run as root or with sudo.
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

[[ $EUID -eq 0 ]] || error "Run as root: sudo bash $0"

if command -v tailscale &>/dev/null; then
    info "Tailscale is already installed."
    tailscale version
else
    info "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    info "Tailscale installed."
fi

# Check if already authenticated
if tailscale status &>/dev/null; then
    info "Tailscale is already authenticated."
    TS_IP=$(tailscale ip -4)
    echo ""
    echo "Tailscale IP: $TS_IP"
    tailscale status
else
    info "Starting Tailscale authentication..."
    echo ""
    warn "A URL will be printed below. Open it in your browser to authorize this device."
    echo ""
    tailscale up

    TS_IP=$(tailscale ip -4 2>/dev/null || echo "unknown")
    echo ""
    info "Tailscale authenticated!"
    echo "Tailscale IP: $TS_IP"
    echo ""
    echo "Next steps:"
    echo "  1. Verify SSH via Tailscale: ssh nazar@$TS_IP"
    echo "  2. Then lock SSH to Tailscale: bash lock-ssh-to-tailscale.sh"
fi
