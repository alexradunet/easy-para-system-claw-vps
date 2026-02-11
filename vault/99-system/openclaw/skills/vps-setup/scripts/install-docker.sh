#!/bin/bash
# install-docker.sh — Install Docker CE + Compose plugin on Debian
# Run as root or with sudo.
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

[[ $EUID -eq 0 ]] || error "Run as root: sudo bash $0"

info "Installing Docker CE on Debian..."

apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg > /dev/null

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null

# Add debian user to docker group if user exists
if id "debian" &>/dev/null; then
    usermod -aG docker debian
    info "Added 'debian' to docker group. Log out and back in for it to take effect."
fi

# Enable Docker on boot
systemctl enable docker

info "Docker installed successfully."
docker --version
docker compose version

echo ""
echo "Verify with:  docker run --rm hello-world"
echo "Note: Log out and back in first if using the 'debian' user."
