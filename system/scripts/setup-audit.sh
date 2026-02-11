#!/bin/bash
#
# Setup audit logging for Nazar
# Tracks file changes, login attempts, and privilege escalations
#

set -e

echo "=== Setting up Audit Logging ==="

# Install auditd
apt-get update -qq
apt-get install -y -qq auditd audispd-plugins

# Configure audit rules
cat > /etc/audit/rules.d/nazar.rules << 'EOF'
# Monitor nazar user activity
-a always,exit -F arch=b64 -S setuid -S setgid -S setreuid -S setregid -k privilege_escalation
-a always,exit -F arch=b32 -S setuid -S setgid -S setreuid -S setregid -k privilege_escalation

# Monitor vault changes
-w /home/nazar/vault/ -p wa -k vault_changes

# Monitor OpenClaw config
-w /home/nazar/.openclaw/ -p wa -k openclaw_config

# Monitor SSH key changes
-w /home/debian/.ssh/ -p wa -k ssh_key_changes

# Monitor sudoers
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d/ -p wa -k sudoers_changes

# Monitor user/group modifications
-w /etc/passwd -p wa -k identity_changes
-w /etc/group -p wa -k identity_changes

# Monitor Tailscale config
-w /etc/default/tailscaled -p wa -k tailscale_config
EOF

# Enable and start auditd
systemctl enable auditd
systemctl restart auditd

# Create log monitoring script
cat > /home/debian/bin/nazar-check-audit << 'EOFMON'
#!/bin/bash
# Check for suspicious activity in audit logs

echo "=== Recent Audit Events ==="
echo ""

# Failed login attempts
echo "--- Failed SSH Logins (last 24h) ---"
ausearch -ts today -k user_logins --success no -i 2>/dev/null | head -20 || echo "None"

echo ""
echo "--- Vault Modifications (last 24h) ---"
ausearch -ts today -k vault_changes -i 2>/dev/null | grep -E "type=PATH|type=SYSCALL" | head -20 || echo "None"

echo ""
echo "--- Privilege Escalation Attempts ---"
ausearch -k privilege_escalation -i 2>/dev/null | tail -10 || echo "None"

echo ""
echo "--- OpenClaw Config Changes ---"
ausearch -ts today -k openclaw_config -i 2>/dev/null | tail -10 || echo "None"
EOFMON

chmod +x /home/debian/bin/nazar-check-audit
chown debian:debian /home/debian/bin/nazar-check-audit

echo "=== Audit logging configured ==="
echo ""
echo "Commands:"
echo "  ausearch -k vault_changes     # View vault modifications"
echo "  ausearch -k privilege_escalation  # View privilege escalation attempts"
echo "  nazar-check-audit             # Quick summary"
