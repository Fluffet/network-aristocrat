#!/bin/bash
# network-aristocrat — WiFi priority class selector for Linux
# Run with: sudo ./network-aristocrat.sh
#
# Sets DSCP (Differentiated Services Code Point) on outgoing packets.
# WiFi access points use WMM (WiFi Multimedia) to prioritize frames based
# on these markings. macOS does this automatically for video calls — Linux
# doesn't, so we do it manually.
#
# WMM queues (highest to lowest priority):
#   AC_VO (voice)  ← DSCP 46 (EF)    — smallest contention window, goes first
#   AC_VI (video)  ← DSCP 34 (AF41)  — shorter contention window than default
#   AC_BE (best-effort) ← default     — what everyone else gets
#   AC_BK (background)                — lowest priority
#
# Only works on networks with WMM enabled (all 802.11n+ APs, i.e. everything).
# Takes effect immediately, persists across reboots.

CHAIN="NETWORK_ARISTOCRAT"

# Video call UDP ports:
#   3478        — STUN/TURN (used by Meet, Zoom, Teams, WebRTC)
#   19302-19309 — Google Meet relay
#   8801-8810   — Zoom media
#   50000-59999 — Microsoft Teams media
CALL_PORTS_STUN="3478"
CALL_PORTS_MEET="19302:19309"
CALL_PORTS_ZOOM="8801:8810"
CALL_PORTS_TEAMS="50000:59999"

set -e

if [ "$EUID" -ne 0 ]; then
    echo "  Need sudo: sudo $0"
    exit 1
fi

if ! command -v iptables &>/dev/null; then
    echo "  iptables not found. Install it first."
    exit 1
fi

setup_chain() {
    # Create our own chain so we don't touch other mangle OUTPUT rules
    iptables -t mangle -N "$CHAIN" 2>/dev/null || true
    ip6tables -t mangle -N "$CHAIN" 2>/dev/null || true

    # Ensure OUTPUT jumps to our chain (only add if not already there)
    if ! iptables -t mangle -C OUTPUT -j "$CHAIN" 2>/dev/null; then
        iptables -t mangle -A OUTPUT -j "$CHAIN"
    fi
    if ! ip6tables -t mangle -C OUTPUT -j "$CHAIN" 2>/dev/null; then
        ip6tables -t mangle -A OUTPUT -j "$CHAIN"
    fi
}

flush_chain() {
    iptables -t mangle -F "$CHAIN" 2>/dev/null || true
    ip6tables -t mangle -F "$CHAIN" 2>/dev/null || true
}

add_rule() {
    iptables -t mangle -A "$CHAIN" "$@"
    ip6tables -t mangle -A "$CHAIN" "$@"
}

detect_mode() {
    local rules
    rules=$(iptables -t mangle -S "$CHAIN" 2>/dev/null)

    if [ -z "$rules" ]; then
        echo "pleb"
    elif echo "$rules" | grep -q -- "-j DSCP.*--set-dscp 0x2e" && \
         ! echo "$rules" | grep -q -- "--dport"; then
        echo "king"
    elif echo "$rules" | grep -q -- "--dport 3478" && \
         echo "$rules" | grep -q -- "-j DSCP.*--set-dscp 0x22"; then
        echo "aristocrat"
    elif echo "$rules" | grep -q -- "--dport 3478" && \
         ! echo "$rules" | grep -q -- "-j DSCP.*--set-dscp 0x22"; then
        echo "meet"
    else
        echo "pleb"
    fi
}

apply_mode() {
    setup_chain
    flush_chain

    case "$1" in
        king)
            add_rule -j DSCP --set-dscp 46
            ;;
        aristocrat)
            add_rule -p udp --dport "$CALL_PORTS_STUN" -j DSCP --set-dscp 46
            add_rule -p udp -m multiport --dports "$CALL_PORTS_MEET" -j DSCP --set-dscp 46
            add_rule -p udp -m multiport --dports "$CALL_PORTS_ZOOM" -j DSCP --set-dscp 46
            add_rule -p udp -m multiport --dports "$CALL_PORTS_TEAMS" -j DSCP --set-dscp 46
            add_rule -j DSCP --set-dscp 34
            ;;
        meet)
            add_rule -p udp --dport "$CALL_PORTS_STUN" -j DSCP --set-dscp 46
            add_rule -p udp -m multiport --dports "$CALL_PORTS_MEET" -j DSCP --set-dscp 46
            add_rule -p udp -m multiport --dports "$CALL_PORTS_ZOOM" -j DSCP --set-dscp 46
            add_rule -p udp -m multiport --dports "$CALL_PORTS_TEAMS" -j DSCP --set-dscp 46
            ;;
        pleb)
            ;;
    esac

    persist_rules
}

persist_rules() {
    # Debian/Ubuntu (iptables-persistent) — check first since /etc/iptables
    # exists on both Arch and Debian, but dpkg is Debian-specific
    if command -v dpkg &>/dev/null && dpkg -l iptables-persistent &>/dev/null 2>&1; then
        iptables-save > /etc/iptables/rules.v4
        ip6tables-save > /etc/iptables/rules.v6
        return
    fi

    # Arch Linux (iptables.service unit exists)
    if systemctl list-unit-files iptables.service &>/dev/null 2>&1; then
        mkdir -p /etc/iptables
        iptables-save > /etc/iptables/iptables.rules
        ip6tables-save > /etc/iptables/ip6tables.rules
        systemctl enable --quiet iptables 2>/dev/null || true
        systemctl enable --quiet ip6tables 2>/dev/null || true
        return
    fi

    # Fedora/RHEL (iptables-services)
    if [ -f /etc/sysconfig/iptables ]; then
        iptables-save > /etc/sysconfig/iptables
        ip6tables-save > /etc/sysconfig/ip6tables
        return
    fi

    echo "  Warning: couldn't detect how to persist rules on this distro."
    echo "  Rules are active now but may not survive a reboot."
}

current=$(detect_mode)

echo ""
echo "  network-aristocrat"
echo "  ━━━━━━━━━━━━━━━━━━"
echo ""
echo "  WiFi routers have priority lanes. Most computers, like all your"
echo "  coworkers with Macs, put video calls in the fast lane automatically."
echo "  Linux doesn't. This script tags your outgoing packets so the router"
echo "  treats them as priority traffic."
echo ""
echo "  Priority tiers:  voice (highest) > video > best-effort > background (lowest)"
echo ""
echo "  1) Network King         All traffic = voice priority. Full main character."
echo "  2) Network Aristocrat   Calls = voice, everything else = video. Classy."
echo "  3) Video Call Boost     Only calls get voice priority. Polite but effective."
echo "  4) Network Pleb         Best-effort like everyone else. Default."
echo ""
echo "  Current: $(
    case $current in
        king)       echo "Network King 👑";;
        aristocrat) echo "Network Aristocrat 🎩";;
        meet)       echo "Video Call Boost 📞";;
        pleb)       echo "Network Pleb 🥔";;
    esac
)"
echo ""
read -rp "  Select [1-4]: " choice

case "$choice" in
    1) apply_mode king;       echo "  → Network King active. All hail." ;;
    2) apply_mode aristocrat; echo "  → Network Aristocrat active. Refined." ;;
    3) apply_mode meet;       echo "  → Video Call Boost active. Just the calls." ;;
    4) apply_mode pleb;       echo "  → Network Pleb. Back among the people." ;;
    *) echo "  Invalid choice." && exit 1 ;;
esac
echo ""
echo "  Verify: watch -n1 'sudo iptables -t mangle -L NETWORK_ARISTOCRAT -v'"
echo ""
