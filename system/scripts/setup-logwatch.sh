#!/bin/bash
#
# Setup log monitoring and alerting
# Sends daily summary of security-relevant events
#

set -e

echo "=== Setting up Log Monitoring ==="

# Install logwatch
apt-get update -qq
apt-get install -y -qq logwatch

# Configure logwatch for security focus
cat > /etc/logwatch/conf/logwatch.conf << 'EOF'
# Logwatch configuration for Nazar
MailTo = root
MailFrom = logwatch@nazar.local
Detail = Med
Service = -zz-disk_space  # Exclude disk space (checked separately)
Service = sshd
Service = fail2ban
Service = audit  # If auditd installed
Service = systemd
Range = yesterday
EOF

# Create wrapper that also checks custom logs
cat > /etc/logwatch/scripts/services/nazar << 'EOF'
#!/bin/bash
# Custom logwatch service for Nazar-specific events

echo "=== Nazar Service Status ==="
systemctl --user -M nazar@ status openclaw --no-pager 2>/dev/null || echo "OpenClaw: cannot check status"
systemctl --user -M nazar@ status syncthing --no-pager 2>/dev/null || echo "Syncthing: cannot check status"

echo ""
echo "=== Tailscale Status ==="
tailscale status 2>/dev/null | head -5 || echo "Tailscale: not available"

echo ""
echo "=== Vault Disk Usage ==="
du -sh /home/nazar/vault 2>/dev/null || echo "Vault: cannot access"
EOF

chmod +x /etc/logwatch/scripts/services/nazar 2>/dev/null || true

# Add cron for daily report
echo "0 6 * * * root /usr/sbin/logwatch --output mail" > /etc/cron.d/logwatch-nazar

echo "=== Log monitoring configured ==="
echo "Daily security report will be emailed to root (install mail if needed)"
