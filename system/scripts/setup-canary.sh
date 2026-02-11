#!/bin/bash
#
# Setup canary files to detect unauthorized access
# If someone reads these files, you'll know the system is compromised
#

set -e

echo "=== Setting up Canary Tokens ==="

# Create fake SSH key (looks real but isn't)
mkdir -p /home/nazar/.ssh
cat > /home/nazar/.ssh/id_rsa_backup << 'EOF'
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACB7KjV5kP8o0yRYD3qRVzFvnR/8zFfExg4lQ/2X4aItzgAAAJiQXUb8kF1G
# This is a FAKE key for canary purposes
# If you're reading this, you've accessed unauthorized files
EOF

chmod 600 /home/nazar/.ssh/id_rsa_backup

# Create fake credentials file
cat > /home/nazar/.aws-credentials << 'EOF'
[default]
aws_access_key_id=AKIAIOSFODNN7EXAMPLE
aws_secret_access_key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
# CANARY: These are fake credentials
# Access logged: $(date -Iseconds)
EOF

chmod 600 /home/nazar/.aws-credentials

# Create fake API keys file
cat > /home/nazar/.env.backup << 'EOF'
# CANARY FILE - DO NOT USE
ANTHROPIC_API_KEY=sk-ant-api03-canary-FAKE-KEY-FOR-DETECTION
OPENAI_API_KEY=sk-canary-fake-key-detection
# If you're reading this, access is unauthorized
EOF

chmod 600 /home/nazar/.env.backup

# Create audit rule for canary files
cat >> /etc/audit/rules.d/nazar.rules << 'EOF'

# Monitor canary files
-w /home/nazar/.ssh/id_rsa_backup -p r -k canary_access
-w /home/nazar/.aws-credentials -p r -k canary_access
-w /home/nazar/.env.backup -p r -k canary_access
EOF

# Restart auditd
systemctl restart auditd 2>/dev/null || true

# Create monitoring script
cat > /home/debian/bin/nazar-check-canary << 'EOF'
#!/bin/bash
# Check if canary files have been accessed

echo "=== Canary Token Check ==="
echo ""

# Check audit logs for canary access
ACCESSED=$(ausearch -k canary_access -ts recent 2>/dev/null | grep -c "type=PATH" || echo "0")

if [ "$ACCESSED" -gt 0 ]; then
    echo "🚨 ALERT: Canary files have been accessed!"
    echo ""
    echo "Access details:"
    ausearch -k canary_access -ts recent -i 2>/dev/null | tail -30
    echo ""
    echo "This indicates unauthorized access to the nazar user account."
    echo "Immediate actions:"
    echo "  1. Check running processes: ps aux | grep nazar"
    echo "  2. Check network connections: ss -tlnp"
    echo "  3. Review recent logins: last"
    echo "  4. Consider rotating all credentials"
else
    echo "✓ No unauthorized access detected"
fi
EOF

chmod +x /home/debian/bin/nazar-check-canary
chown debian:debian /home/debian/bin/nazar-check-canary

# Add to crontab for regular checks
echo "*/30 * * * * root /home/debian/bin/nazar-check-canary 2>/dev/null | logger -t canary-check" > /etc/cron.d/canary-check

echo "=== Canary tokens configured ==="
echo ""
echo "Fake sensitive files created:"
echo "  /home/nazar/.ssh/id_rsa_backup"
echo "  /home/nazar/.aws-credentials"
echo "  /home/nazar/.env.backup"
echo ""
echo "If these files are read, an alert is logged."
echo "Check with: nazar-check-canary"
