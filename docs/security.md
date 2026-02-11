# Security Model

This document describes the security architecture of the Nazar Second Brain system.

## Threat Model

### What We're Protecting Against

1. **Unauthorized SSH access** — Brute force, credential theft
2. **Service compromise** — OpenClaw or Syncthing exploited
3. **Data exfiltration** — Vault contents stolen
4. **Privilege escalation** — From service user to root
5. **Network attacks** — Man-in-the-middle, sniffing

### What We Assume

- VPS provider is trusted
- Tailscale infrastructure is trusted
- User's devices (laptop, phone) are not compromised
- Physical access to VPS is controlled by provider

## Security Architecture

### 1. Network Security

**Tailscale VPN (WireGuard)**
- All services only accessible via Tailscale IPs (`100.x.x.x`)
- No public ports exposed
- End-to-end encryption
- Device authentication required

**UFW Firewall**
```
Default: deny incoming
Default: allow outgoing
Allow: 22/tcp on tailscale0 only (SSH)
```

### 2. Authentication

**SSH**
- Key-based authentication only (no passwords)
- Root login disabled
- `AllowUsers debian` — only admin can SSH
- Fail2Ban: 3 failed attempts = 1 hour ban

**OpenClaw Gateway**
- Token-based authentication
- Random 256-bit token generated at setup
- Device pairing required for web UI

**Syncthing**
- Device ID authentication (cryptographic)
- Admin password on GUI
- Optional HTTPS for GUI

### 3. User Isolation

| User | UID | Groups | Can Do |
|------|-----|--------|--------|
| `root` | 0 | - | Everything (no SSH access) |
| `debian` | 1000 | sudo | Admin tasks, system updates |
| `nazar` | 1001 | nazar | Run services, access vault |

**Key protections:**
- `nazar` has **no sudo access** — cannot escalate privileges
- `nazar` password is **locked** — cannot login via password
- `nazar` home directory: `drwx------` (700) — only owner can read

### 4. Process Isolation (Systemd)

**OpenClaw Service:**
```ini
NoNewPrivileges=true    # Cannot gain new capabilities
PrivateTmp=true         # Private /tmp
ProtectSystem=strict    # Read-only root filesystem
ProtectHome=read-only   # Read-only other home directories
ReadWritePaths=/home/nazar/vault /home/nazar/.openclaw
```

**Syncthing Service:**
Same restrictions as OpenClaw.

This means even if the service is compromised:
- Cannot write outside vault and config directories
- Cannot read other users' home directories
- Cannot modify system files

### 5. Data Protection

**Vault**
- Stored at `/home/nazar/vault/` (mode 700)
- Synced via Syncthing (encrypted in transit via Tailscale)
- Versioning enabled (protects against ransomware/deletion)

**Secrets**
- API keys in `/home/nazar/.openclaw/` (mode 700)
- Never in vault (which is synced)
- Not in environment variables visible to all processes

## Security Checklist

Run `nazar-audit` (as debian user) to verify:

```bash
$ nazar-audit
=== Nazar Security Audit ===

✓ Root login disabled
✓ Password authentication disabled
✓ nazar user has no sudo access
✓ nazar user password locked
✓ UFW firewall active
✓ Fail2Ban running
✓ Auto-updates enabled
✓ Tailscale connected
✓ nazar home directory restricted (700)
✓ OpenClaw config directory restricted (700)

Results: 10 passed, 0 failed
✅ All security checks passed!
```

## Hardening Recommendations

### 1. Lock SSH to Tailscale Only

After confirming Tailscale SSH works:

```bash
# Remove public SSH
sudo ufw delete allow 22/tcp

# Allow only on Tailscale interface
sudo ufw allow in on tailscale0 to any port 22 proto tcp comment 'SSH via Tailscale only'
sudo ufw reload
```

### 2. Enable Syncthing HTTPS

```bash
# Edit Syncthing config
nano /home/nazar/.local/state/syncthing/config.xml

# Change GUI address and enable TLS
<gui enabled="true" tls="true">
    <address>127.0.0.1:8384</address>
    ...
</gui>

# Restart
sudo -u nazar systemctl --user restart syncthing
```

Access via Tailscale Serve:
```bash
tailscale serve --https=443 http://localhost:8384
```

### 3. Enable Full Disk Encryption (if supported)

Some VPS providers support disk encryption:
- Hetzner: Available at provisioning time
- OVH: Check control panel options

### 4. Set Up Off-Site Backups

```bash
# Create encrypted backup to external Git
sudo -u nazar bash -c '
    cd /home/nazar/vault
    git init
    git remote add backup git@github.com:youruser/encrypted-vault.git
    git add -A
    git commit -m "Backup $(date)"
    git push -u backup main
'
```

### 5. Disable nazar Shell (After Setup)

Once everything is working:

```bash
# Prevent any login as nazar
sudo usermod -s /usr/sbin/nologin nazar

# To temporarily allow (for debugging):
# sudo usermod -s /bin/bash nazar
```

## Incident Response

### If You Suspect Compromise

1. **Isolate**: Disconnect from Tailscale
   ```bash
   sudo tailscale down
   ```

2. **Preserve logs**:
   ```bash
   sudo cp /var/log/auth.log ~/auth.log.backup
   sudo -u nazar journalctl --user -u openclaw > ~/openclaw.log.backup
   ```

3. **Check for persistence**:
   ```bash
   # Check cron jobs
   sudo crontab -u nazar -l
   
   # Check systemd services
   ls -la /home/nazar/.config/systemd/user/
   
   # Check for new SSH keys
   cat /home/nazar/.ssh/authorized_keys 2>/dev/null || echo "No SSH keys"
   ```

4. **Rotate credentials**:
   - Change OpenClaw token: `sudo -u nazar openclaw configure`
   - Rotate API keys (Anthropic, OpenAI, etc.)
   - Regenerate Tailscale auth key

5. **Rebuild**: If unsure, provision fresh VPS and restore vault from backup

### Reporting Security Issues

If you discover a security vulnerability:
1. Do not open a public issue
2. Email security details to [your-email]
3. Allow time for fix before disclosure

## Comparison with Docker Version

| Security Aspect | Docker Version | Direct Version |
|-----------------|----------------|----------------|
| Container escape risk | Present | N/A (no container) |
| User privilege separation | Single user | Two users (better) |
| Process capabilities | Docker-managed | Systemd restrictions |
| Attack surface | Docker daemon | Standard Unix |
| Audit complexity | Higher (layers) | Lower (simpler) |

**Bottom line**: The direct version has **comparable security** with **simpler auditing**.

## Optional Security Enhancements

Run `sudo bash system/scripts/setup-all-security.sh` for interactive hardening:

### 1. Audit Logging
Tracks all file changes, privilege escalations, and access attempts.
```bash
sudo bash system/scripts/setup-audit.sh
```
**Features:**
- Monitor vault modifications
- Track SSH key changes
- Log privilege escalation attempts
- Command: `nazar-check-audit`

### 2. File Integrity Monitoring (AIDE)
Detects unauthorized file modifications.
```bash
sudo bash system/scripts/setup-integrity.sh
```
**Features:**
- Baseline of critical system files
- Daily automated checks
- Alerts on changes
- Command: `nazar-check-integrity`

### 3. Egress Firewall
Blocks unwanted outbound connections to prevent data exfiltration.
```bash
sudo bash system/scripts/setup-egress-firewall.sh
```
**Features:**
- Block all outbound except HTTPS, DNS, Tailscale
- Prevents C2 communication if compromised
- **Warning:** Test thoroughly, may break some features

### 4. Canary Tokens
Fake sensitive files that trigger alerts if accessed.
```bash
sudo bash system/scripts/setup-canary.sh
```
**Features:**
- Fake SSH keys, AWS credentials, API keys
- Automatic audit logging on access
- Potential automatic lockdown
- Command: `nazar-check-canary`

### 5. Encrypted Backups
GPG-encrypted vault backups with automatic rotation.
```bash
sudo bash system/scripts/setup-backup.sh
```
**Features:**
- 4096-bit RSA encryption
- Automatic daily backups
- 30-day retention
- Commands: `nazar-backup`, `nazar-restore`

### 6. Automatic Security Response
Monitors and responds to security events automatically.
```bash
sudo bash system/scripts/setup-auto-response.sh
```
**Features:**
- Real-time log monitoring
- Automatic IP banning
- Critical alert escalation
- Service lockdown on breach detection

## Security Level Comparison

| Level | Configuration | Use Case |
|-------|--------------|----------|
| **Basic** | Bootstrap defaults only | Personal use, low threat |
| **Standard** | + Audit + Backups + Canary | Important personal data |
| **High** | + Integrity + Auto-response | Sensitive information |
| **Maximum** | + Egress firewall | High-value target, journalists, activists |

## References

- [Tailscale Security](https://tailscale.com/security)
- [Syncthing Security](https://docs.syncthing.net/users/security.html)
- [Systemd Service Security](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#Security)
- [Debian Security Manual](https://www.debian.org/doc/manuals/securing-debian-howto/)
- [AIDE Documentation](https://aide.github.io/)
- [Auditd Best Practices](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/security_hardening/auditing-the-system_security-hardening)
