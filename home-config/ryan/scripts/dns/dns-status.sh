#!/usr/bin/env bash
# Stylized Catppuccin Mocha DNS, WARP & Tor Proxy status & Pango tooltip for Waybar
# Modes (derived strictly from live systemd unit & interface states so Waybar is always accurate):
#   - off:    Standard NetworkManager / DHCP DNS & direct IP routing
#   - direct: Encrypted Cloudflare DoH via dnscrypt-proxy (127.0.0.1:53), direct IP
#   - warp:   Cloudflare WARP WireGuard tunnel (warp0 -> Cloudflare IP) +
#             Cloudflare DoH via dnscrypt-proxy (127.0.0.1:53)
#   - tor:    Full Tor Transparent TCP Proxy (TransPort 9040 -> exit node IP) +
#             Cloudflare DoH routed over Tor SOCKS5 (127.0.0.1:9050)

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
rm -f /tmp/dns-debug.log /tmp/dns-debug2.log /tmp/dns-debug3.log /tmp/test-dnscrypt.toml 2>/dev/null

# Detect live service & interface status
tor_active=0
direct_active=0
tor_dns_active=0
warp_active=0
units_installed=0

[ -e /etc/systemd/system/dns-proxy-warp.service ] && units_installed=1
systemctl is-active --quiet tor.service 2>/dev/null && tor_active=1
systemctl is-active --quiet dnscrypt-proxy-direct.service 2>/dev/null && direct_active=1
systemctl is-active --quiet dnscrypt-proxy-tor.service 2>/dev/null && tor_dns_active=1
[ -d /sys/class/net/warp0 ] && warp_active=1

# Determine mode strictly from live active services/interfaces so UI never shows a false state
if [ "$tor_dns_active" -eq 1 ] && [ "$tor_active" -eq 1 ]; then
    mode="tor"
elif [ "$warp_active" -eq 1 ] && [ "$direct_active" -eq 1 ]; then
    mode="warp"
elif [ "$direct_active" -eq 1 ]; then
    mode="direct"
else
    mode="off"
fi

# Read active nameservers from /etc/resolv.conf
resolv_servers=$(awk '/^nameserver/ {print $2}' /etc/resolv.conf 2>/dev/null | paste -sd ', ' -)
[ -z "$resolv_servers" ] && resolv_servers="none"

m_off="<span foreground='#6c7086'>off</span>"
m_direct="<span foreground='#6c7086'>direct</span>"
m_warp="<span foreground='#6c7086'>warp</span>"
m_tor="<span foreground='#6c7086'>tor</span>"

case "$mode" in
    direct)
        m_direct="<span foreground='#74c7ec' weight='bold'>[direct doh]</span>"
        route_str="<span foreground='#74c7ec' weight='bold'>127.0.0.1:53 → Cloudflare DoH (HTTPS)</span>"
        ip_route="<span foreground='#a6adc8'>Direct ISP IP (DNS encrypted only)</span>"
        r_off="  <span foreground='#6c7086'>○ Off (DHCP)            Plaintext DNS · Direct IP</span>"
        r_dir="  <span foreground='#74c7ec' weight='bold'>● Direct (DNSCrypt)     Cloudflare DoH · Direct IP     ←</span>"
        r_wrp="  <span foreground='#6c7086'>○ WARP + DNSCrypt       Cloudflare IP (warp0) + DoH</span>"
        r_tor="  <span foreground='#6c7086'>○ Tor + DNSCrypt        Tor Exit IP (9040) + DoH (9050)</span>"
        ;;
    warp)
        m_warp="<span foreground='#fab387' weight='bold'>[warp + doh]</span>"
        route_str="<span foreground='#fab387' weight='bold'>127.0.0.1:53 → warp0 → Cloudflare DoH</span>"
        ip_route="<span foreground='#fab387' weight='bold'>Cloudflare WARP Tunnel (WireGuard warp0 · CF IP)</span>"
        r_off="  <span foreground='#6c7086'>○ Off (DHCP)            Plaintext DNS · Direct IP</span>"
        r_dir="  <span foreground='#6c7086'>○ Direct (DNSCrypt)     Cloudflare DoH · Direct IP</span>"
        r_wrp="  <span foreground='#fab387' weight='bold'>● WARP + DNSCrypt       Cloudflare IP (warp0) + DoH    ←</span>"
        r_tor="  <span foreground='#6c7086'>○ Tor + DNSCrypt        Tor Exit IP (9040) + DoH (9050)</span>"
        ;;
    tor)
        m_tor="<span foreground='#cba6f7' weight='bold'>[tor + doh]</span>"
        route_str="<span foreground='#cba6f7' weight='bold'>127.0.0.1:53 → Tor (9050) → Cloudflare DoH</span>"
        ip_route="<span foreground='#cba6f7' weight='bold'>Tor Transparent Proxy (TransPort 9040 · Exit IP)</span>"
        r_off="  <span foreground='#6c7086'>○ Off (DHCP)            Plaintext DNS · Direct IP</span>"
        r_dir="  <span foreground='#6c7086'>○ Direct (DNSCrypt)     Cloudflare DoH · Direct IP</span>"
        r_wrp="  <span foreground='#6c7086'>○ WARP + DNSCrypt       Cloudflare IP (warp0) + DoH</span>"
        r_tor="  <span foreground='#cba6f7' weight='bold'>● Tor + DNSCrypt        Tor Exit IP (9040) + DoH (9050) ←</span>"
        ;;
    *)
        mode="off"
        m_off="<span foreground='#94e2d5' weight='bold'>[off (dhcp)]</span>"
        route_str="<span foreground='#a6adc8'>NetworkManager DHCP (${resolv_servers})</span>"
        ip_route="<span foreground='#a6adc8'>Direct ISP IP</span>"
        r_off="  <span foreground='#94e2d5' weight='bold'>● Off (DHCP)            Plaintext DNS · Direct IP      ←</span>"
        r_dir="  <span foreground='#6c7086'>○ Direct (DNSCrypt)     Cloudflare DoH · Direct IP</span>"
        r_wrp="  <span foreground='#6c7086'>○ WARP + DNSCrypt       Cloudflare IP (warp0) + DoH</span>"
        r_tor="  <span foreground='#6c7086'>○ Tor + DNSCrypt        Tor Exit IP (9040) + DoH (9050)</span>"
        ;;
esac

if [ "$direct_active" -eq 1 ] || [ "$tor_dns_active" -eq 1 ]; then
    dnscrypt_state="<span foreground='#a6e3a1' weight='bold'>active (127.0.0.1:53)</span>"
else
    dnscrypt_state="<span foreground='#6c7086'>stopped</span>"
fi

if [ "$warp_active" -eq 1 ]; then
    warp_state="<span foreground='#fab387' weight='bold'>active (WireGuard warp0 · 172.16.0.2)</span>"
else
    warp_state="<span foreground='#6c7086'>stopped</span>"
fi

if [ "$tor_active" -eq 1 ]; then
    tor_state="<span foreground='#cba6f7' weight='bold'>active (TransPort 9040 · SOCKS 9050)</span>"
else
    tor_state="<span foreground='#6c7086'>stopped (saves battery)</span>"
fi

if [ "$resolv_servers" = "127.0.0.1" ]; then
    resolv_str="<span foreground='#a6e3a1' weight='bold'>127.0.0.1</span> <span foreground='#6c7086'>(exclusive lo.dnscrypt)</span>"
else
    resolv_str="<span foreground='#cdd6f4' weight='bold'>${resolv_servers}</span> <span foreground='#6c7086'>(DHCP)</span>"
fi

tt="<span foreground='#94e2d5' weight='bold'>󰦝  DNS, WARP &amp; Tor Routing Control</span>\n"
tt+="<span foreground='#45475a'>─────────────────────────────────────────────────</span>\n"
tt+="  Active Mode:    ${m_off} <span foreground='#6c7086'>/</span> ${m_direct} <span foreground='#6c7086'>/</span> ${m_warp} <span foreground='#6c7086'>/</span> ${m_tor}\n"
tt+="  /etc/resolv:    ${resolv_str}\n"
tt+="  DNS Path:       ${route_str}\n"
tt+="  Traffic / IP:   ${ip_route}\n"
tt+="  DNSCrypt Svc:   ${dnscrypt_state}\n"
tt+="  WARP Tunnel:    ${warp_state}\n"
tt+="  Tor Daemon:     ${tor_state}\n"
if [ "$units_installed" -eq 0 ]; then
    tt+="\n<span foreground='#f38ba8' weight='bold'>  ⚠ Pending Rebuild: Run 'sudo nixos-rebuild switch --flake ~/nixos'</span>\n"
fi
tt+="\n<span foreground='#cba6f7' weight='bold'>── Routing Profiles ─────────────────────────────</span>\n"
tt+="${r_off}\n"
tt+="${r_dir}\n"
tt+="${r_wrp}\n"
tt+="${r_tor}\n"
tt+="<span foreground='#6c7086'><i>Left-click: DNS Mode Menu  ·  Right-click: Cycle Mode</i></span>"

case "$mode" in
    direct)
        printf '{"text":"󰦝 doh","class":"direct","tooltip":"%s"}\n' "$tt"
        ;;
    warp)
        printf '{"text":"󰅠 warp","class":"warp","tooltip":"%s"}\n' "$tt"
        ;;
    tor)
        printf '{"text":"󰒃 tor","class":"tor","tooltip":"%s"}\n' "$tt"
        ;;
    *)
        printf '{"text":"󰇖 dns","class":"off","tooltip":"%s"}\n' "$tt"
        ;;
esac
