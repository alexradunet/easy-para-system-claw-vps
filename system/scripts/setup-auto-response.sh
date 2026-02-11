#!/bin/bash
#
# Setup automatic response to security events
# Blocks IPs, sends alerts on suspicious activity
#

set -e

echo "=== Setting up Automatic Security Response ==="

# Create fail2ban local config for stricter SSH rules
cat > /etc/fail2ban/jail.d/nazar-ssh.conf << 'EOF'
[sshd]
enabled = true
backend = systemd
maxretry = 3
bantime = 3600
findtime = 600
# Ban for 24 hours on 3rd offense
bantime.increment = true
bantime.factor = 2
bantime.maxtime = 86400
EOF

# Create custom filter for OpenClaw (if needed)
cat > /etc/fail2ban/filter.d/openclaw.conf << 'EOF'
[Definition]
failregex = ^.*Unauthorized.*from <HOST>.*$
            ^.*Invalid token.*from <HOST>.*$
ignoreregex = 
EOF

# Create alert script
cat > /usr/local/bin/nazar-security-alert << 'EOF'
#!/bin/bash
# Send security alert

EVENT="$1"
DETAILS="$2"
HOSTNAME=$(hostname)
DATE=$(date -Iseconds)

# Log to syslog
logger -t nazar-security -p user.alert "SECURITY ALERT: $EVENT on $HOSTNAME"

# Also log to file
mkdir -p /var/log/nazar
echo "[$DATE] $HOSTNAME: $EVENT - $DETAILS" >> /var/log/nazar/security-alerts.log

# If mail is configured, send email
if command -v mail &> /dev/null; then
    echo -e "Security Event: $EVENT\n\nHostname: $HOSTNAME\nTime: $DATE\n\nDetails:\n$DETAILS" | \
        mail -s "[SECURITY] $EVENT on $HOSTNAME" root 2>/dev/null || true
fi

# Check if we should lock down (high severity)
if [[ "$EVENT" == *"CANARY"* ]] || [[ "$EVENT" == *"PRIVILEGE"* ]]; then
    logger -t nazar-security -p user.emerg "CRITICAL: Initiating lockdown"
    
    # Lock nazar user
    usermod -L nazar 2>/dev/null || true
    
    # Stop services
    su - nazar -c "systemctl --user stop openclaw syncthing" 2>/dev/null || true
    
    # Could also disconnect Tailscale:
    # tailscale down
fi
EOF

chmod +x /usr/local/bin/nazar-security-alert

# Create monitoring daemon (simple script)
cat > /home/debian/bin/nazar-security-monitor << 'EOF'
#!/bin/bash
# Security monitoring daemon
# Run this as a systemd service or cron job

LOG_FILE="/var/log/nazar/security-monitor.log"
mkdir -p /var/log/nazar

log() {
    echo "[$(date -Iseconds)] $1" | tee -a "$LOG_FILE"
}

log "Security monitor started"

# Check for canary access
if ausearch -k canary_access -ts recent 2>/dev/null | grep -q "type=PATH"; then
    log "ALERT: Canary files accessed!"
    /usr/local/bin/nazar-security-alert "CANARY_ACCESS" "Canary files were read - possible breach"
fi

# Check for multiple failed SSH attempts
FAILED_SSH=$(grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l)
if [ "$FAILED_SSH" -gt 10 ]; then
    log "WARNING: $FAILED_SSH failed SSH attempts detected"
fi

# Check for new sudoers entries
if [ -f /etc/sudoers.d/.baseline ]; then
    if ! diff -q /etc/sudoers.d/.baseline /etc/sudoers.d/ > /dev/null 2>&1; then
        log "ALERT: Sudoers configuration changed!"
        /usr/local/bin/nazar-security-alert "SUDOERS_CHANGED" "Sudoers files modified"
    fi
else
    # Create baseline
    cp /etc/sudoers /etc/sudoers.d/.baseline 2>/dev/null || true
fi

# Check for unauthorized processes running as nazar
NAZAR_PROCS=$(ps -u nazar -o comm= 2>/dev/null | grep -v -E "^(syncthing|openclaw|gpg-agent|dbus-daemon|ssh-agent)$" | head -5)
if [ -n "$NAZAR_PROCS" ]; then
    log "WARNING: Unexpected processes as nazar: $NAZAR_PROCS"
fi

# Check vault permissions
VAULT_PERM=$(stat -c "%a" /home/nazar/vault 2>/dev/null)
if [ "$VAULT_PERM" != "700" ]; then
    log "ALERT: Vault permissions changed to $VAULT_PERM!"
    /usr/local/bin/nazar-security-alert "VAULT_PERMISSIONS" "Vault permissions changed from 700 to $VAULT_PERM"
fi

log "Security monitor check complete"
EOF

chmod +x /home/debian/bin/nazar-security-monitor
chown debian:debian /home/debian/bin/nazar-security-monitor

# Add to cron (every 5 minutes)
echo "*/5 * * * * debian /home/debian/bin/nazar-security-monitor 2>&1 | logger -t nazar-monitor" > /etc/cron.d/nazar-security-monitor

# Create systemd service for continuous monitoring (optional)
cat > /etc/systemd/system/nazar-security-monitor.service << 'EOF'
[Unit]
Description=Nazar Security Monitor
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'while true; do /home/debian/bin/nazar-security-monitor; sleep 300; done'
Restart=always
User=debian

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable nazar-security-monitor 2>/dev/null || true

echo "=== Automatic security response configured ==="
echo ""
echo "Features:"
echo "  - Stricter fail2ban rules"
echo "  - Canary file monitoring"
echo "  - Automatic lockdown on critical alerts"
echo "  - Permission change detection"
echo "  - Process monitoring"
echo ""
echo "Check alerts: /var/log/nazar/security-alerts.log"
echo "Monitor log: /var/log/nazar/security-monitor.log"
