# network-aristocrat

Your coworkers' computers have operating systems that put WiFi packets in first class when doing important things. You're on Linux, it doesn't always do smart and convenient things, so your packets are traveling economy class, and you're wondering why your Google Meet looks like a 2007 webcam when everyone else at the same WiFi has pristine quality.

This script allows you to mark your outgoing packets with other traffic tiers. There are 4: voice > video > best-effort > background.

WiFi access points see those tags and go "ah yes, right this way sir." Your Linux? Sadly, every packet gets the "best-effort" treatment. Your Meet call is effectively in the same queue as someone's iCloud backup.

This has been the case since... forever. There are iptables one-liners buried in forum posts from 2010. There's a kernel doc that three people have read. Thought I'd publish this tool you can just run and finally elbow your way into pristine HD.

So here it is. One script. Pick your network class, or caste, if you will.

If you don't want to stop at just fixing calls, you can become a Network King or Network Aristocrat. This will mark every outgoing packet as Voice or Video, which has highest priority; your cloud backups are as important as their video calls. They're backups, right? Pretty important if you ask me.

## Install

```bash
git clone https://github.com/Fluffet/network-aristocrat.git
cd network-aristocrat
chmod +x network-aristocrat.sh
sudo ./network-aristocrat.sh
```

## What it looks like

```
  network-aristocrat
  ━━━━━━━━━━━━━━━━━━

  WiFi routers have priority lanes. Most computers, like all your
  coworkers with Macs, put video calls in the fast lane automatically.
  Linux doesn't. This script tags your outgoing packets so the router
  treats them as priority traffic.

  Priority tiers:  voice (highest) > video > best-effort > background (lowest)

  1) Network King         All traffic = voice priority. Full main character.
  2) Network Aristocrat   Calls = voice, everything else = video. Classy.
  3) Video Call Boost     Only calls get voice priority. Polite but effective.
  4) Network Pleb         Best-effort like everyone else. Default.

  Current: Network Pleb 🥔

  Select [1-4]:
```

## How it works

WiFi access points use WMM (WiFi Multimedia) to sort traffic into priority
queues. WMM has been mandatory since 802.11n (2009). Every router you'll
encounter supports it.

The queues, highest to lowest:

| Queue | Priority | Used for |
|-------|----------|----------|
| AC_VO (voice) | Highest | VoIP, video calls |
| AC_VI (video) | High | Streaming, interactive |
| AC_BE (best-effort) | Normal | Everything on Linux by default |
| AC_BK (background) | Low | Backups, updates |

The AP decides which queue your packet goes in based on the DSCP value in the
IP header. macOS sets this automatically for video calls. Linux doesn't. This
script sets it with iptables.

The AP doesn't inspect what's in your packets. It just reads the tag. It has no
idea if it's a 30kbps voice stream or your cloud backup.

## Modes

| Mode | Calls | Everything else | Vibe |
|------|-------|-----------------|------|
| Network King | voice (highest) | voice (highest) | Main character |
| Network Aristocrat | voice (highest) | video (high) | Classy |
| Video Call Boost | voice (highest) | best-effort | Polite |
| Network Pleb | best-effort | best-effort | Suffering |

## Supported video call apps

The script tags UDP traffic for:
- **Google Meet** (ports 3478, 19302-19309)
- **Zoom** (ports 3478, 8801-8810)
- **Microsoft Teams** (ports 3478, 50000-59999)
- Any WebRTC app using STUN/TURN (port 3478)

Both IPv4 and IPv6 traffic are tagged.

## Will this get me in trouble?

No. DSCP marking is a standard IP feature. Your machine is allowed to set
whatever header values it wants on its own packets. Really handy at cafés,
coworking spaces, hotels or airports.

The worst case: a network admin notices unusual WMM queue usage, thinks "huh,
weird," and does nothing. There are usually no network admins at your local café anyway.

## Does it work everywhere?

Anywhere with WMM enabled, which is every 802.11n+ access point since 2009.
So yes, everywhere. Coffee shops, coworking spaces, airports, hotels, your
office. Enterprise networks with explicit QoS policies *might* strip your
markings, but most don't bother.

## Requirements

- Linux
- iptables + ip6tables
- sudo

## Persists across reboots?

Yes. The script auto-detects your distro and saves rules to the right place:
- **Arch Linux** — `/etc/iptables/iptables.rules` + `systemctl enable iptables`
- **Debian/Ubuntu** — `/etc/iptables/rules.v4` (via iptables-persistent)
- **Fedora/RHEL** — `/etc/sysconfig/iptables` (via iptables-services)

If your distro isn't detected, the script warns you. Rules are still active
until reboot — you just need to figure out persistence yourself.

## Safe to run alongside other iptables rules?

Yes. The script uses its own chain (`NETWORK_ARISTOCRAT`) instead of modifying
the OUTPUT chain directly. Your firewall rules, VPN, Docker — all untouched.

## Uninstall

```bash
sudo iptables -t mangle -D OUTPUT -j NETWORK_ARISTOCRAT
sudo iptables -t mangle -F NETWORK_ARISTOCRAT
sudo iptables -t mangle -X NETWORK_ARISTOCRAT
sudo ip6tables -t mangle -D OUTPUT -j NETWORK_ARISTOCRAT
sudo ip6tables -t mangle -F NETWORK_ARISTOCRAT
sudo ip6tables -t mangle -X NETWORK_ARISTOCRAT
```

## Verify it works

```bash
# Watch packet counters go up in real time
watch -n1 'sudo iptables -t mangle -L NETWORK_ARISTOCRAT -v'

# Check your Meet packets are tagged (during a call)
sudo tcpdump -i wlan0 -n -c 10 'udp port 19302 or udp port 3478' -v 2>&1 | grep tos
# tos 0xb8 = voice priority ✓
# tos 0x0  = pleb ✗
```

## SEO

- Linux WiFi slow Google Meet
- Linux video call choppy but Mac works fine
- WiFi priority Linux
- Why does my WiFi suck on Linux
- Linux Google Meet bad quality
- Linux Zoom call bad quality
- Linux Teams call laggy
- macOS WiFi faster than Linux same network
- WiFi QoS Linux desktop
- iptables DSCP Google Meet
- WMM Linux priority
- Linux WiFi coworking space slow
- My coworkers' Macs work fine but my Linux laptop doesn't
- Framework laptop WiFi issues Linux
- How to prioritize WiFi traffic on Linux
- Linux WiFi packet priority
- Why is my WiFi worse than everyone else's
- It's not your WiFi. It's your OS not asking nicely.
