#!/bin/bash
#
# Setup file integrity monitoring for critical files
# Uses AIDE (Advanced Intrusion Detection Environment)
#

set -e

echo "=== Setting up File Integrity Monitoring ==="

# Install AIDE
apt-get update -qq
apt-get install -y -qq aide

# Initialize AIDE database (this takes a while)
echo "Initializing AIDE database (this may take a few minutes)..."
aideinit || true

# Copy to production location
cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# Create check script
cat > /home/debian/bin/nazar-check-integrity << 'EOF'
#!/bin/bash
# Check file integrity

echo "=== File Integrity Check ==="
echo "Checking for modified system files..."
echo ""

# Run AIDE check
aide --check 2>&1 | tee /tmp/aide-check-$$(date +%Y%m%d).log | grep -E "(changed|added|removed):" || echo "No changes detected"

echo ""
echo "Full report saved to: /tmp/aide-check-$(date +%Y%m%d).log"
EOF

chmod +x /home/debian/bin/nazar-check-integrity
chown debian:debian /home/debian/bin/nazar-check-integrity

# Add cron job for daily checks
echo "0 3 * * * root /usr/bin/aide --check | mail -s \"AIDE Check $(hostname)\" root 2>/dev/null || true" > /etc/cron.d/aide-check

echo "=== File integrity monitoring configured ==="
echo ""
echo "Commands:"
echo "  nazar-check-integrity    # Check for file changes"
echo "  aide --update            # Update baseline (after legitimate changes)"
