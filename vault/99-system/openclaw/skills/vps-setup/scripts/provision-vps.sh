#!/bin/bash
# provision-vps.sh — Master provisioning script for a fresh Debian VPS
#
# Runs all phases in order:
#   1. Harden VPS (user, SSH, firewall, fail2ban, auto-updates)
#   2. Install Tailscale (interactive — requires browser auth)
#   3. Install Docker
#   4. Deploy Nazar stack
#
# Usage:
#   ssh root@<vps-ip>
#   curl -O <raw-url-to-this-script>   # or scp it
#   bash provision-vps.sh [--deploy-repo /path/to/deploy]
#
# Run as root on a fresh Debian VPS.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOY_REPO=""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
header()  { echo -e "\n${BLUE}============================================${NC}"; echo -e "${BLUE}  $*${NC}"; echo -e "${BLUE}============================================${NC}\n"; }

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --deploy-repo) DEPLOY_REPO="$2"; shift 2 ;;
        *) error "Unknown argument: $1" ;;
    esac
done

[[ $EUID -eq 0 ]] || error "Run as root: sudo bash $0"

echo ""
echo "  ╔═══════════════════════════════════════╗"
echo "  ║     Nazar VPS Provisioning Script     ║"
echo "  ║        Debian + Tailscale             ║"
echo "  ║     OpenClaw + Git Vault Sync         ║"
echo "  ╚═══════════════════════════════════════╝"
echo ""

# ─────────────────────────────────────────────
header "Phase 1/8: System Update"
# ─────────────────────────────────────────────
info "Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq > /dev/null
apt-get install -y -qq curl git > /dev/null
info "System updated."

# ─────────────────────────────────────────────
header "Phase 2/8: Verify Default User"
# ─────────────────────────────────────────────
if id "debian" &>/dev/null; then
    info "User 'debian' exists."
else
    error "Default 'debian' user not found. This script expects the cloud provider's default user."
fi

# Ensure debian has passwordless sudo
if ! sudo -u debian sudo -n true 2>/dev/null; then
    info "Granting debian passwordless sudo..."
    echo "debian ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/debian
    chmod 0440 /etc/sudoers.d/debian
fi

# Copy root SSH keys if debian doesn't have any
if [ -f /root/.ssh/authorized_keys ] && [ ! -f /home/debian/.ssh/authorized_keys ]; then
    mkdir -p /home/debian/.ssh
    cp /root/.ssh/authorized_keys /home/debian/.ssh/authorized_keys
    chown -R debian:debian /home/debian/.ssh
    chmod 700 /home/debian/.ssh
    chmod 600 /home/debian/.ssh/authorized_keys
    info "Copied root SSH keys to debian."
fi

# Verify
su - debian -c "sudo -n whoami" | grep -q root || error "debian user cannot sudo. Fix before continuing."
info "User 'debian' verified."

# ─────────────────────────────────────────────
header "Phase 3/8: Harden SSH + Firewall + Fail2Ban"
# ─────────────────────────────────────────────

# SSH hardening
info "Hardening SSH..."
tee /etc/ssh/sshd_config.d/hardened.conf > /dev/null << 'EOF'
PermitRootLogin no
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
MaxAuthTries 3
MaxSessions 3
LoginGraceTime 30
KbdInteractiveAuthentication no
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding yes
AllowUsers debian
EOF
sshd -t || error "SSH config invalid!"

# Firewall
info "Configuring firewall..."
apt-get install -y -qq ufw > /dev/null
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment "SSH"
ufw --force enable
systemctl restart sshd
info "SSH + firewall configured."

# Fail2Ban
info "Installing Fail2Ban..."
apt-get install -y -qq fail2ban > /dev/null
tee /etc/fail2ban/jail.local > /dev/null << 'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 3

[sshd]
enabled = true
port = ssh
backend = systemd
maxretry = 3
bantime = 3600
EOF
systemctl enable fail2ban
systemctl restart fail2ban
info "Fail2Ban active."

# Unattended upgrades
info "Enabling automatic security updates..."
apt-get install -y -qq unattended-upgrades apt-listchanges > /dev/null
tee /etc/apt/apt.conf.d/50unattended-upgrades > /dev/null << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "04:00";
EOF
tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
systemctl enable unattended-upgrades
systemctl restart unattended-upgrades
info "Auto-updates enabled."

# ─────────────────────────────────────────────
header "Phase 4/8: Install Tailscale"
# ─────────────────────────────────────────────
if command -v tailscale &>/dev/null && tailscale status &>/dev/null; then
    info "Tailscale already installed and authenticated."
else
    if ! command -v tailscale &>/dev/null; then
        info "Installing Tailscale..."
        curl -fsSL https://tailscale.com/install.sh | sh
    fi
    echo ""
    warn "═══════════════════════════════════════════════════════"
    warn "  INTERACTIVE STEP: Tailscale authentication required"
    warn "  A URL will appear — open it in your browser."
    warn "═══════════════════════════════════════════════════════"
    echo ""
    tailscale up
fi

TS_IP=$(tailscale ip -4 2>/dev/null || echo "")
if [ -z "$TS_IP" ]; then
    error "Tailscale IP not found. Authentication may have failed."
fi
info "Tailscale IP: $TS_IP"

# ─────────────────────────────────────────────
header "Phase 5/8: Lock SSH to Tailscale"
# ─────────────────────────────────────────────
echo ""
warn "Before locking SSH to Tailscale, test from another terminal:"
warn "  ssh debian@$TS_IP"
echo ""
read -p "Can you SSH via Tailscale? (yes/no): " CONFIRM_TS

if [ "$CONFIRM_TS" = "yes" ]; then
    info "Locking SSH to Tailscale..."
    ufw delete allow 22/tcp 2>/dev/null || true
    ufw allow in on tailscale0 to any port 22 comment "SSH-via-Tailscale"
    ufw reload
    info "SSH now Tailscale-only."
else
    warn "Skipping Tailscale SSH lockdown. Public SSH remains open."
    warn "Run lock-ssh-to-tailscale.sh later when ready."
fi

# ─────────────────────────────────────────────
header "Phase 6/8: Install Docker"
# ─────────────────────────────────────────────
if command -v docker &>/dev/null; then
    info "Docker already installed."
else
    info "Installing Docker CE..."
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
    systemctl enable docker
    info "Docker installed."
fi
usermod -aG docker debian 2>/dev/null || true
info "User 'debian' added to docker group."

# Add openclaw CLI alias for debian user
if ! grep -q 'alias openclaw=' /home/debian/.bashrc 2>/dev/null; then
    echo 'alias openclaw="sudo docker exec -it nazar-gateway node dist/index.js"' >> /home/debian/.bashrc
    info "Added 'openclaw' CLI alias for debian user."
fi

# Verify
docker --version
docker compose version

# ─────────────────────────────────────────────
header "Phase 7/8: Deploy Nazar Stack"
# ─────────────────────────────────────────────
NAZAR_ROOT="/srv/nazar"
OPENCLAW_SRC="/opt/openclaw"

info "Creating directory structure..."
mkdir -p "$NAZAR_ROOT"/{vault,data/openclaw,scripts}
chown -R 1000:1000 "$NAZAR_ROOT"

# Clone OpenClaw source
if [ ! -d "$OPENCLAW_SRC" ]; then
    info "Cloning OpenClaw source..."
    git clone https://github.com/openclaw/openclaw.git "$OPENCLAW_SRC"
else
    info "OpenClaw source exists at $OPENCLAW_SRC"
fi

# Find deploy repo
if [ -z "$DEPLOY_REPO" ]; then
    # Try common locations
    for candidate in "$SCRIPT_DIR/.." /srv/nazar/deploy /home/debian/deploy; do
        if [ -f "$candidate/docker-compose.yml" ]; then
            DEPLOY_REPO="$candidate"
            break
        fi
    done
fi

if [ -z "$DEPLOY_REPO" ] || [ ! -f "$DEPLOY_REPO/docker-compose.yml" ]; then
    warn "Deploy repo not found."
    warn "Copy it to /srv/nazar/deploy/ and re-run, or pass --deploy-repo /path"
    warn "Skipping stack deployment."
else
    info "Using deploy repo at: $DEPLOY_REPO"

    # Overlay files
    cp "$DEPLOY_REPO/Dockerfile.nazar" "$OPENCLAW_SRC/Dockerfile.nazar"
    cp "$DEPLOY_REPO/docker-compose.yml" "$NAZAR_ROOT/docker-compose.yml"
    cp "$DEPLOY_REPO/openclaw.json" "$NAZAR_ROOT/data/openclaw/openclaw.json"

    # Create .env
    if [ ! -f "$NAZAR_ROOT/.env" ]; then
        cp "$DEPLOY_REPO/.env.example" "$NAZAR_ROOT/.env"
        TOKEN=$(openssl rand -hex 32)
        sed -i "s/generate-with-openssl-rand-hex-32/$TOKEN/" "$NAZAR_ROOT/.env"
        info "Generated gateway token in .env"
    else
        info ".env already exists, keeping it."
    fi
    chown debian:debian "$NAZAR_ROOT/.env"

    # Add swap if low memory (< 2GB)
    TOTAL_MEM=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    if [ "$TOTAL_MEM" -lt 2048 ] && [ ! -f /swapfile ]; then
        info "Low memory detected (${TOTAL_MEM}MB). Adding 2GB swap..."
        fallocate -l 2G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
        info "Swap enabled."
    fi

    # Build and start
    info "Building Docker images (this may take several minutes)..."
    cd "$NAZAR_ROOT"
    docker compose build 2>&1 | tail -5
    docker compose up -d
    info "Containers started."
fi

# ─────────────────────────────────────────────
header "Provisioning Complete!"
# ─────────────────────────────────────────────

TS_IP=$(tailscale ip -4 2>/dev/null || echo "<tailscale-ip>")

echo ""
echo "  ┌───────────────────────────────────────────┐"
echo "  │           Access Information               │"
echo "  ├───────────────────────────────────────────┤"
TS_HOSTNAME=$(tailscale status --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['Self']['DNSName'].rstrip('.'))" 2>/dev/null || echo "<tailscale-hostname>")
echo "  │  SSH:        ssh debian@$TS_IP"
echo "  │  Gateway:    https://$TS_HOSTNAME/"
echo "  ├───────────────────────────────────────────┤"
echo "  │           Next Steps                       │"
echo "  ├───────────────────────────────────────────┤"
echo "  │  1. Run: openclaw configure                  │"
echo "  │  2. Run audit: bash audit-vps.sh           │"
echo "  └───────────────────────────────────────────┘"
echo ""
echo "Firewall status:"
ufw status numbered
echo ""
echo "Docker status:"
cd /srv/nazar && docker compose ps 2>/dev/null || echo "(containers not yet deployed)"
