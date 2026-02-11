#!/bin/bash
#
# Setup egress firewall to limit outbound connections
# Prevents data exfiltration if service is compromised
#

set -e

echo "=== Setting up Egress Firewall ==="

# Install iptables-persistent for rules that survive reboot
apt-get update -qq
apt-get install -y -qq iptables-persistent

# Save current rules
iptables-save > /etc/iptables/rules.v4.bak.$(date +%Y%m%d)

# Define allowed outbound connections for nazar user
# Only allow: DNS, HTTPS (APIs), Tailscale

iptables -F OUTPUT 2>/dev/null || true
iptables -P OUTPUT DROP

# Allow loopback
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established connections
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow DNS
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Allow HTTPS (APIs: Anthropic, OpenAI, etc.)
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

# Allow Tailscale
iptables -A OUTPUT -p udp --dport 3478 -j ACCEPT  # STUN
iptables -A OUTPUT -p udp --dport 41641 -j ACCEPT # Tailscale wireguard

# Allow NTP (time sync)
iptables -A OUTPUT -p udp --dport 123 -j ACCEPT

# Save rules
iptables-save > /etc/iptables/rules.v4

# Create nazar-specific restrictions (optional stricter rules)
# These require iptables owner module

# Block nazar user from accessing non-HTTPS outbound
echo "Note: User-specific egress rules require advanced iptables configuration"
echo "Current setup blocks ALL outbound except allowed services for ALL users"

echo "=== Egress firewall configured ==="
echo ""
echo "Allowed outbound:"
echo "  - DNS (port 53)"
echo "  - HTTPS (port 443)"
echo "  - Tailscale (ports 3478, 41641)"
echo "  - NTP (port 123)"
echo ""
echo "Blocked: All other outbound connections"
echo ""
echo "Commands:"
echo "  iptables -L OUTPUT -v    # View rules"
echo "  iptables -F OUTPUT       # Flush rules (emergency)"
