# Security Features Summary

This document provides a quick overview of all security features available in the Nazar Second Brain system.

## Quick Start

```bash
# Run the security hardening menu
sudo bash system/scripts/setup-all-security.sh
```

## Security Layers

### Layer 1: Base Security (Always Enabled)

These are applied automatically by `bootstrap.sh`:

| Feature | Implementation | Purpose |
|---------|---------------|---------|
| **SSH Hardening** | `sshd_config.d/nazar.conf` | Keys only, no root, no passwords |
| **User Isolation** | `debian` + `nazar` users | Privilege separation |
| **Firewall** | UFW | Deny all incoming, Tailscale only |
| **Fail2Ban** | `jail.local` | Block brute-force attempts |
| **Auto-updates** | `unattended-upgrades` | Automatic security patches |
| **Service Sandboxing** | systemd security options | Process restrictions |
| **Home Directory** | mode 700 | Private user data |
| **Audit Script** | `nazar-audit` | Verify security posture |

**Status:** ✅ Enabled by default

### Layer 2: Monitoring (Recommended)

Enable with `setup-all-security.sh`:

| Feature | Script | Purpose |
|---------|--------|---------|
| **Audit Logging** | `setup-audit.sh` | Track all system changes |
| **File Integrity** | `setup-integrity.sh` | Detect file tampering |
| **Log Monitoring** | `setup-logwatch.sh` | Daily security reports |

**Commands:**
```bash
nazar-check-audit      # View recent audit events
nazar-check-integrity  # Check file integrity
```

**Status:** ⬜ Optional, recommended

### Layer 3: Intrusion Detection (High Security)

Enable with `setup-all-security.sh`:

| Feature | Script | Purpose |
|---------|--------|---------|
| **Canary Tokens** | `setup-canary.sh` | Detect unauthorized file access |
| **Auto Response** | `setup-auto-response.sh` | Automatic threat response |

**Commands:**
```bash
nazar-check-canary     # Check for canary triggers
```

**Features:**
- Fake SSH keys that trigger alerts if read
- Fake API credential files
- Automatic lockdown on critical alerts
- Real-time process monitoring

**Status:** ⬜ Optional, for sensitive data

### Layer 4: Data Protection (Recommended)

Enable with `setup-all-security.sh`:

| Feature | Script | Purpose |
|---------|--------|---------|
| **Encrypted Backups** | `setup-backup.sh` | GPG-encrypted vault backups |

**Commands:**
```bash
nazar-backup           # Create encrypted backup
nazar-restore <file>   # Restore from backup
```

**Features:**
- 4096-bit RSA encryption
- Automatic daily backups
- 30-day retention
- Secure key management

**Status:** ⬜ Optional, strongly recommended

### Layer 5: Network Lockdown (Advanced)

Enable with `setup-all-security.sh`:

| Feature | Script | Purpose |
|---------|--------|---------|
| **Egress Firewall** | `setup-egress-firewall.sh` | Block unwanted outbound traffic |

**Features:**
- Block all outbound except HTTPS, DNS, Tailscale
- Prevent data exfiltration
- Prevent C2 communication

**Warning:** May break some functionality. Test thoroughly.

**Status:** ⬜ Optional, for high-security environments

## Security Checklist

After initial setup, verify security:

```bash
# Run as debian user
nazar-audit
```

Expected output:
```
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

## Incident Response

### If You Suspect Compromise

1. **Check canary tokens:**
   ```bash
   nazar-check-canary
   ```

2. **Review audit logs:**
   ```bash
   sudo ausearch -k vault_changes -ts recent
   ```

3. **Check file integrity:**
   ```bash
   nazar-check-integrity
   ```

4. **Isolate if needed:**
   ```bash
   sudo tailscale down                    # Disconnect VPN
   sudo -u nazar systemctl --user stop openclaw syncthing
   sudo passwd -l nazar                   # Lock service user
   ```

5. **Preserve evidence:**
   ```bash
   sudo cp /var/log/auth.log ~/auth.log.emergency
   sudo -u nazar journalctl --user -u openclaw > ~/openclaw.log.emergency
   ```

### Recovery

1. Provision new VPS
2. Restore from encrypted backup:
   ```bash
   nazar-restore /path/to/backup.tar.gz.gpg
   ```
3. Rotate all API keys
4. Review and update Tailscale ACLs

## Security Comparison

| Threat | Basic | +Monitoring | +Detection | +Lockdown |
|--------|-------|-------------|------------|-----------|
| Brute force SSH | ✅ Fail2Ban | ✅ +Audit | ✅ +Alerts | ✅ +Auto-ban |
| Privilege escalation | ✅ No sudo | ✅ +Audit | ✅ +Detection | ✅ +Lockdown |
| Data exfiltration | ✅ Tailscale | ✅ +Audit | ✅ +Canary | ✅ +Egress fw |
| File tampering | ✅ Permissions | ✅ +AIDE | ✅ +Alerts | ✅ +Response |
| Unauthorized access | ✅ SSH keys | ✅ +Logging | ✅ +Tokens | ✅ +Lockdown |

## Recommendations by Use Case

### Personal Journal / Notes
- **Level:** Basic
- **Features:** Bootstrap defaults only
- **Rationale:** Low-value target, convenience优先

### Work Projects / Client Data
- **Level:** Standard
- **Features:** + Audit + Backups + Integrity
- **Rationale:** Important data, need audit trail

### Sensitive Research / Journalism
- **Level:** High
- **Features:** + All except egress firewall
- **Rationale:** High-value target, active threats

### Maximum Security / High-Risk
- **Level:** Maximum
- **Features:** All enhancements including egress firewall
- **Rationale:** Critical data, sophisticated adversaries

## Security Contacts

If you discover a security vulnerability:
1. Do not open a public issue
2. Email: [your-security-email]
3. Allow 30 days for fix before disclosure

---

**Last Updated:** 2026-02-11
**Security Version:** 1.0
