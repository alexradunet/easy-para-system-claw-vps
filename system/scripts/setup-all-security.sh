#!/bin/bash
#
# Master script to apply all optional security hardening
# Run this after the main bootstrap for enhanced security
#

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Nazar Second Brain - Security Hardening Menu           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

show_menu() {
    echo "Available security enhancements:"
    echo ""
    echo "  1) Audit Logging         - Track file changes and privilege escalation"
    echo "  2) File Integrity        - Detect unauthorized file modifications"
    echo "  3) Egress Firewall       - Block unwanted outbound connections"
    echo "  4) Log Monitoring        - Daily security reports via email"
    echo "  5) Canary Tokens         - Detect unauthorized access to sensitive files"
    echo "  6) Encrypted Backups     - GPG-encrypted vault backups"
    echo "  7) Auto Security Response- Automatic response to threats"
    echo ""
    echo "  a) Apply ALL enhancements"
    echo "  s) Show current security status"
    echo "  q) Quit"
    echo ""
}

apply_enhancement() {
    local script="$1"
    local name="$2"
    
    echo ""
    echo "=== Applying: $name ==="
    if [ -f "$SCRIPT_DIR/$script" ]; then
        bash "$SCRIPT_DIR/$script"
        echo "✓ $name applied"
    else
        echo "✗ Script not found: $SCRIPT_DIR/$script"
    fi
}

show_status() {
    echo ""
    echo "=== Current Security Status ==="
    echo ""
    
    # Run basic audit
    if [ -f /home/debian/bin/nazar-audit ]; then
        su - debian -c "nazar-audit" 2>/dev/null || echo "Audit script not available"
    else
        echo "Basic audit not configured yet"
    fi
    
    echo ""
    echo "Installed enhancements:"
    
    # Check each enhancement
    dpkg -l | grep -q auditd && echo "  ✓ Audit Logging" || echo "  ✗ Audit Logging"
    dpkg -l | grep -q aide && echo "  ✓ File Integrity" || echo "  ✗ File Integrity"
    [ -f /home/debian/bin/nazar-check-canary ] && echo "  ✓ Canary Tokens" || echo "  ✗ Canary Tokens"
    [ -f /home/debian/bin/nazar-backup ] && echo "  ✓ Encrypted Backups" || echo "  ✗ Encrypted Backups"
    [ -f /etc/cron.d/nazar-security-monitor ] && echo "  ✓ Auto Response" || echo "  ✗ Auto Response"
    
    echo ""
}

# Main loop
while true; do
    show_menu
    read -p "Select option (1-7, a, s, q): " choice
    
    case $choice in
        1)
            apply_enhancement "setup-audit.sh" "Audit Logging"
            ;;
        2)
            apply_enhancement "setup-integrity.sh" "File Integrity Monitoring"
            ;;
        3)
            apply_enhancement "setup-egress-firewall.sh" "Egress Firewall"
            echo "⚠️  WARNING: Egress firewall may break some functionality!"
            echo "    Test thoroughly before keeping enabled."
            ;;
        4)
            apply_enhancement "setup-logwatch.sh" "Log Monitoring"
            ;;
        5)
            apply_enhancement "setup-canary.sh" "Canary Tokens"
            ;;
        6)
            apply_enhancement "setup-backup.sh" "Encrypted Backups"
            ;;
        7)
            apply_enhancement "setup-auto-response.sh" "Auto Security Response"
            ;;
        a|A)
            echo ""
            echo "Applying ALL security enhancements..."
            echo "This will take several minutes."
            read -p "Continue? (yes/no): " confirm
            if [ "$confirm" = "yes" ]; then
                apply_enhancement "setup-audit.sh" "Audit Logging"
                apply_enhancement "setup-integrity.sh" "File Integrity"
                apply_enhancement "setup-logwatch.sh" "Log Monitoring"
                apply_enhancement "setup-canary.sh" "Canary Tokens"
                apply_enhancement "setup-backup.sh" "Encrypted Backups"
                apply_enhancement "setup-auto-response.sh" "Auto Response"
                echo ""
                echo "✓ All enhancements applied!"
                echo ""
                echo "NOTE: Egress firewall was NOT applied automatically."
                echo "      Run option 3 separately if needed."
            fi
            ;;
        s|S)
            show_status
            ;;
        q|Q)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done
