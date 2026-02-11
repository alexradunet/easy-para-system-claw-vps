#!/bin/bash
#
# Setup encrypted backups of the vault
# Uses GPG encryption before storing remotely
#

set -e

echo "=== Setting up Encrypted Backups ==="

# Install tools
apt-get update -qq
apt-get install -y -qq gnupg2 gzip

# Generate backup encryption key (if not exists)
if [ ! -f /home/debian/.backup-gpg-key ]; then
    echo "Generating backup encryption key..."
    
    # Create key without passphrase (for automated backups)
    export GNUPGHOME=$(mktemp -d)
    cat > $GNUPGHOME/gen-key-script << 'EOF'
%echo Generating backup key
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: Nazar Backup Key
Name-Email: backup@nazar.local
Expire-Date: 0
%no-protection
%commit
%echo done
EOF
    
    gpg --batch --gen-key $GNUPGHOME/gen-key-script 2>/dev/null
    
    # Export public key
    gpg --export backup@nazar.local > /home/debian/.backup-gpg-key.pub
    
    # Export private key (store securely!)
    gpg --export-secret-keys backup@nazar.local > /home/debian/.backup-gpg-key
    chmod 600 /home/debian/.backup-gpg-key
    chown debian:debian /home/debian/.backup-gpg-key*
    
    rm -rf $GNUPGHOME
    
    echo "✓ Backup key generated"
    echo "⚠️  IMPORTANT: Store /home/debian/.backup-gpg-key somewhere safe OFF the VPS!"
    echo "   This is required to decrypt backups. If lost, backups are useless."
fi

# Create backup script
cat > /home/debian/bin/nazar-backup << 'EOF'
#!/bin/bash
# Create encrypted backup of vault

BACKUP_DIR="${BACKUP_DIR:-/home/debian/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
GPG_KEY="${GPG_KEY:-/home/debian/.backup-gpg-key.pub}"

mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/nazar-vault-$TIMESTAMP.tar.gz.gpg"

echo "Creating backup: $BACKUP_FILE"

# Create compressed, encrypted backup
sudo tar czf - -C /home/nazar vault 2>/dev/null | \
    gpg --encrypt --recipient-file "$GPG_KEY" --trust-model always > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "✓ Backup created: $BACKUP_FILE"
    ls -lh "$BACKUP_FILE"
    
    # Clean old backups
    echo "Cleaning backups older than $RETENTION_DAYS days..."
    find "$BACKUP_DIR" -name "nazar-vault-*.tar.gz.gpg" -mtime +$RETENTION_DAYS -delete
    
    echo "Backups retained:"
    ls -lh "$BACKUP_DIR"
else
    echo "✗ Backup failed"
    exit 1
fi
EOF

chmod +x /home/debian/bin/nazar-backup
chown debian:debian /home/debian/bin/nazar-backup

# Create restore script
cat > /home/debian/bin/nazar-restore << 'EOF'
#!/bin/bash
# Restore vault from encrypted backup

if [ $# -eq 0 ]; then
    echo "Usage: nazar-restore <backup-file>"
    echo ""
    echo "Available backups:"
    ls -lh /home/debian/backups/*.gpg 2>/dev/null || echo "  No backups found"
    exit 1
fi

BACKUP_FILE="$1"
GPG_KEY="${GPG_KEY:-/home/debian/.backup-gpg-key}"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Backup file not found: $BACKUP_FILE"
    exit 1
fi

if [ ! -f "$GPG_KEY" ]; then
    echo "Error: GPG private key not found: $GPG_KEY"
    exit 1
fi

echo "WARNING: This will OVERWRITE the current vault!"
echo "Backup file: $BACKUP_FILE"
read -p "Are you sure? Type 'yes' to continue: " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

# Stop services
echo "Stopping services..."
sudo -u nazar systemctl --user stop openclaw syncthing 2>/dev/null || true

# Backup current vault first
echo "Backing up current vault..."
sudo mv /home/nazar/vault "/home/nazar/vault.backup.$(date +%Y%m%d-%H%M%S)"

# Restore
echo "Restoring from backup..."
gpg --decrypt --batch --yes --passphrase-fd 0 "$BACKUP_FILE" 2>/dev/null < "$GPG_KEY" | \
    sudo tar xzf - -C /home/nazar

# Fix permissions
sudo chown -R nazar:nazar /home/nazar/vault

# Restart services
echo "Restarting services..."
sudo -u nazar systemctl --user start syncthing openclaw

echo "✓ Restore complete"
echo "Previous vault saved to: /home/nazar/vault.backup.*"
EOF

chmod +x /home/debian/bin/nazar-restore
chown debian:debian /home/debian/bin/nazar-restore

# Create directory for backups
mkdir -p /home/debian/backups
chown debian:debian /home/debian/backups

# Add cron for daily backups
echo "0 2 * * * debian /home/debian/bin/nazar-backup >> /home/debian/backups/backup.log 2>&1" > /etc/cron.d/nazar-backup

echo "=== Encrypted backups configured ==="
echo ""
echo "Commands:"
echo "  nazar-backup           # Create backup now"
echo "  nazar-restore <file>   # Restore from backup"
echo ""
echo "Backups stored in: /home/debian/backups/"
echo "Automatic backups: Daily at 2:00 AM"
echo "Retention: 30 days"
echo ""
echo "⚠️  IMPORTANT: Download /home/debian/.backup-gpg-key to a secure location!"
echo "   Without this key, you cannot decrypt backups."
