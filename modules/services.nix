{ pkgs, lib, ... }:
let
    # Base DNSCrypt-Proxy configuration using Cloudflare's static DoH stamp so
    # it starts answering queries on 127.0.0.1:53 immediately without needing an
    # unencrypted bootstrap fetch of public-resolvers.md first.
    dnscryptBaseToml = ''
        listen_addresses = ["127.0.0.1:53", "[::1]:53"]
        server_names = ["cloudflare", "cloudflare-backup"]
        ipv4_servers = true
        ipv6_servers = false
        doh_servers = true
        require_dnssec = false
        require_nolog = true
        require_nofilter = false
        ignore_system_dns = true
        netprobe_timeout = 0
        cache = true
        cache_size = 4096
        cache_min_ttl = 2400
        cache_max_ttl = 86400
        cache_neg_min_ttl = 60
        cache_neg_max_ttl = 600
    '';

    # Unpinned DoH stamps for 1.1.1.1 and 1.0.0.1 (dns.cloudflare.com/dns-query)
    # so dnscrypt-proxy validates TLS against the system CA bundle instead of failing
    # on expired DigiCert certificate hashes.
    dnscryptCloudflareStatic = ''
        [static.cloudflare]
        stamp = "sdns://AgcAAAAAAAAABzEuMS4xLjEAEmRucy5jbG91ZGZsYXJlLmNvbQovZG5zLXF1ZXJ5"

        [static.cloudflare-backup]
        stamp = "sdns://AgcAAAAAAAAABzEuMC4wLjEAEmRucy5jbG91ZGZsYXJlLmNvbQovZG5zLXF1ZXJ5"
    '';

    # Forward .onion and .exit queries over UDP directly to Tor's DNSPort (127.0.0.1:9053)
    # so AutomapHostsOnResolve maps them into VirtualAddrNetworkIPv4 (10.192.0.0/10).
    torOnionForwarding = pkgs.writeText "tor-onion-forwarding.txt" ''
        onion 127.0.0.1:9053
        exit 127.0.0.1:9053
    '';

    dnscryptDirectConf = pkgs.writeText "dnscrypt-proxy-direct.toml" ''
        ${dnscryptBaseToml}
        dnscrypt_servers = true
        timeout = 5000
        keepalive = 30

        ${dnscryptCloudflareStatic}
    '';

    # In Tor mode, DoH HTTPS (TCP/443) is transparently routed through Tor TransPort 9040
    # by TOR_PROXY, while omitting `proxy`/`force_tcp` keeps forwarding_rules on UDP so
    # Tor's UDP-only DNSPort (127.0.0.1:9053) resolves .onion domains cleanly.
    dnscryptTorConf = pkgs.writeText "dnscrypt-proxy-tor.toml" ''
        ${dnscryptBaseToml}
        dnscrypt_servers = false
        timeout = 10000
        keepalive = 30
        forwarding_rules = "${torOnionForwarding}"

        ${dnscryptCloudflareStatic}
    '';

    # Wait up to 5s for dnscrypt-proxy to bind 127.0.0.1:53 (0100007F:0035) before
    # pointing /etc/resolv.conf or running wgcf bootstrap queries against it.
    waitDnsPort53 = pkgs.writeShellScript "wait-dns-port-53" ''
        for _ in $(seq 1 50); do
            if grep -q "0100007F:0035" /proc/net/udp /proc/net/tcp 2>/dev/null; then
                exit 0
            fi
            sleep 0.1
        done
    '';

    # Helper script to remove Tor transparent proxy iptables/ip6tables chains
    stopTorTransProxy = pkgs.writeShellScript "stop-tor-transproxy" ''
        ${pkgs.iptables}/bin/iptables -t nat -D OUTPUT -p tcp -j TOR_PROXY 2>/dev/null || true
        ${pkgs.iptables}/bin/iptables -t nat -F TOR_PROXY 2>/dev/null || true
        ${pkgs.iptables}/bin/iptables -t nat -X TOR_PROXY 2>/dev/null || true

        ${pkgs.iptables}/bin/iptables -t filter -D OUTPUT -j TOR_FILTER 2>/dev/null || true
        ${pkgs.iptables}/bin/iptables -F TOR_FILTER 2>/dev/null || true
        ${pkgs.iptables}/bin/iptables -X TOR_FILTER 2>/dev/null || true

        ${pkgs.iptables}/bin/ip6tables -t filter -D OUTPUT -j TOR_FILTER6 2>/dev/null || true
        ${pkgs.iptables}/bin/ip6tables -F TOR_FILTER6 2>/dev/null || true
        ${pkgs.iptables}/bin/ip6tables -X TOR_FILTER6 2>/dev/null || true
    '';

    # Helper script to enable Tor transparent TCP proxy (TransPort 9040) + block UDP/IPv6/keepalive leaks
    startTorTransProxy = pkgs.writeShellScript "start-tor-transproxy" ''
        ${stopTorTransProxy}

        # 1. NAT chain: DNAT Tor's automapped .onion range (10.192.0.0/10) BEFORE the
        #    RFC1918 10.0.0.0/8 LAN exemption, then DNAT all non-LAN outbound TCP to TransPort 9040
        ${pkgs.iptables}/bin/iptables -t nat -N TOR_PROXY
        ${pkgs.iptables}/bin/iptables -t nat -A TOR_PROXY -m owner --uid-owner tor -j RETURN
        ${pkgs.iptables}/bin/iptables -t nat -A TOR_PROXY -d 10.192.0.0/10 -p tcp -m tcp --syn -j DNAT --to-destination 127.0.0.1:9040
        for net in 127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 100.64.0.0/10 169.254.0.0/16 224.0.0.0/4 240.0.0.0/4; do
            ${pkgs.iptables}/bin/iptables -t nat -A TOR_PROXY -d "$net" -j RETURN
        done
        ${pkgs.iptables}/bin/iptables -t nat -A TOR_PROXY -p tcp -m tcp --syn -j DNAT --to-destination 127.0.0.1:9040
        ${pkgs.iptables}/bin/iptables -t nat -A OUTPUT -p tcp -j TOR_PROXY

        # 2. Filter chain:
        #    - Allow traffic owned by tor and traffic destined to 127.0.0.0/8 (including DNAT'd 127.0.0.1:9040)
        #    - Reject non-DNAT'd (e.g. UDP) packets to 10.192.0.0/10 before the 10.0.0.0/8 LAN exemption
        #    - Reject pre-existing ESTABLISHED direct TCP sockets with TCP RST so browsers immediately
        #      open a fresh connection through Tor TransPort 9040 (changing your IP without tab reloads)
        #    - Reject non-LAN outbound UDP (e.g. QUIC UDP:443) so browsers fall back to TCP over Tor
        ${pkgs.iptables}/bin/iptables -t filter -N TOR_FILTER
        ${pkgs.iptables}/bin/iptables -t filter -A TOR_FILTER -m owner --uid-owner tor -j RETURN
        ${pkgs.iptables}/bin/iptables -t filter -A TOR_FILTER -d 127.0.0.0/8 -j RETURN
        ${pkgs.iptables}/bin/iptables -t filter -A TOR_FILTER -d 10.192.0.0/10 -j REJECT --reject-with icmp-port-unreachable
        for net in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 100.64.0.0/10 169.254.0.0/16 224.0.0.0/4 255.255.255.255/32; do
            ${pkgs.iptables}/bin/iptables -t filter -A TOR_FILTER -d "$net" -j RETURN
        done
        ${pkgs.iptables}/bin/iptables -t filter -A TOR_FILTER -p tcp -j REJECT --reject-with tcp-reset
        ${pkgs.iptables}/bin/iptables -t filter -A TOR_FILTER -p udp -j REJECT --reject-with icmp-port-unreachable
        ${pkgs.iptables}/bin/iptables -t filter -A OUTPUT -j TOR_FILTER

        # 3. IPv6 filter chain: reject non-local IPv6 traffic so dual-stack connections
        # use IPv4 TCP through Tor TransPort 9040 instead of leaking IPv6 address
        ${pkgs.iptables}/bin/ip6tables -t filter -N TOR_FILTER6
        ${pkgs.iptables}/bin/ip6tables -t filter -A TOR_FILTER6 -m owner --uid-owner tor -j RETURN
        ${pkgs.iptables}/bin/ip6tables -t filter -A TOR_FILTER6 -d ::1/128 -j RETURN
        ${pkgs.iptables}/bin/ip6tables -t filter -A TOR_FILTER6 -d fe80::/10 -j RETURN
        ${pkgs.iptables}/bin/ip6tables -t filter -A TOR_FILTER6 -p tcp -j REJECT --reject-with tcp-reset
        ${pkgs.iptables}/bin/ip6tables -t filter -A TOR_FILTER6 -j REJECT --reject-with icmp6-adm-prohibited
        ${pkgs.iptables}/bin/ip6tables -t filter -A OUTPUT -j TOR_FILTER6
    '';

    # Helper script to tear down Cloudflare WARP WireGuard interface (warp0)
    stopWarpTunnel = pkgs.writeShellScript "stop-warp-tunnel" ''
        export PATH="${pkgs.iproute2}/bin:${pkgs.iptables}/bin:${pkgs.wireguard-tools}/bin:${pkgs.openresolv}/bin:${pkgs.procps}/bin:${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin:${pkgs.gnused}/bin:${pkgs.gawk}/bin:$PATH"

        ${pkgs.iptables}/bin/iptables -t filter -D OUTPUT -j WARP_FILTER 2>/dev/null || true
        ${pkgs.iptables}/bin/iptables -t filter -F WARP_FILTER 2>/dev/null || true
        ${pkgs.iptables}/bin/iptables -t filter -X WARP_FILTER 2>/dev/null || true

        ${pkgs.iptables}/bin/ip6tables -t filter -D OUTPUT -j WARP_FILTER6 2>/dev/null || true
        ${pkgs.iptables}/bin/ip6tables -t filter -F WARP_FILTER6 2>/dev/null || true
        ${pkgs.iptables}/bin/ip6tables -t filter -X WARP_FILTER6 2>/dev/null || true

        if [ -f /var/lib/wgcf/warp0.conf ] && ${pkgs.iproute2}/bin/ip link show warp0 >/dev/null 2>&1; then
            ${pkgs.wireguard-tools}/bin/wg-quick down /var/lib/wgcf/warp0.conf 2>/dev/null || ${pkgs.iproute2}/bin/ip link del dev warp0 2>/dev/null || true
        elif ${pkgs.iproute2}/bin/ip link show warp0 >/dev/null 2>&1; then
            ${pkgs.iproute2}/bin/ip link del dev warp0 2>/dev/null || true
        fi
    '';

    # Helper script to auto-register wgcf (first run only) and bring up Cloudflare WARP (warp0)
    startWarpTunnel = pkgs.writeShellScript "start-warp-tunnel" ''
        set -e
        export PATH="${pkgs.iproute2}/bin:${pkgs.iptables}/bin:${pkgs.wireguard-tools}/bin:${pkgs.openresolv}/bin:${pkgs.procps}/bin:${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin:${pkgs.gnused}/bin:${pkgs.gawk}/bin:$PATH"

        ${stopWarpTunnel}

        mkdir -p /var/lib/wgcf
        chmod 700 /var/lib/wgcf
        cd /var/lib/wgcf

        if [ ! -f /var/lib/wgcf/wgcf-account.toml ]; then
            ${pkgs.wgcf}/bin/wgcf register --accept-tos
        fi

        if [ ! -f /var/lib/wgcf/wgcf-profile.conf ]; then
            ${pkgs.wgcf}/bin/wgcf generate
        fi

        # Strip DNS lines (handled by dnscrypt-proxy-direct on 127.0.0.1:53) and use
        # Cloudflare WARP's direct anycast IPv4 endpoint so wg-quick never blocks on DNS
        ${pkgs.gnugrep}/bin/grep -v '^DNS *=' /var/lib/wgcf/wgcf-profile.conf \
            | ${pkgs.gnused}/bin/sed 's/engage\.cloudflareclient\.com:2408/162.159.192.1:2408/g' \
            > /var/lib/wgcf/warp0.conf
        chmod 600 /var/lib/wgcf/warp0.conf

        ${pkgs.wireguard-tools}/bin/wg-quick up /var/lib/wgcf/warp0.conf

        # Reset pre-existing TCP/UDP sockets still bound to the LAN source IP so browsers
        # immediately open fresh connections through warp0 (172.16.0.2) without hanging
        ${pkgs.iptables}/bin/iptables -t filter -N WARP_FILTER
        ${pkgs.iptables}/bin/iptables -t filter -A WARP_FILTER -o warp0 ! -s 172.16.0.0/12 -p tcp -j REJECT --reject-with tcp-reset
        ${pkgs.iptables}/bin/iptables -t filter -A WARP_FILTER -o warp0 ! -s 172.16.0.0/12 -p udp -j REJECT --reject-with icmp-port-unreachable
        ${pkgs.iptables}/bin/iptables -t filter -A OUTPUT -j WARP_FILTER

        ${pkgs.iptables}/bin/ip6tables -t filter -N WARP_FILTER6
        ${pkgs.iptables}/bin/ip6tables -t filter -A WARP_FILTER6 -o warp0 ! -s 2606:4700::/32 -p tcp -j REJECT --reject-with tcp-reset
        ${pkgs.iptables}/bin/ip6tables -t filter -A WARP_FILTER6 -o warp0 ! -s 2606:4700::/32 -p udp -j REJECT --reject-with icmp6-adm-prohibited
        ${pkgs.iptables}/bin/ip6tables -t filter -A OUTPUT -j WARP_FILTER6
    '';

    # Dedicated ThinkFan YAML curves so ThinkFan stays running in all 3 modes (`auto`, `quiet`, `max`),
    # preventing ThinkPad's 120s hardware EC fan watchdog from resetting manual overrides while
    # preserving an emergency thermal ceiling in `quiet` mode.
    mkThinkfanYaml = name: levelsYaml: pkgs.writeText "thinkfan-${name}.yaml" ''
        %YAML 1.1
        ---
        fans:
        - tpacpi: /proc/acpi/ibm/fan
        sensors:
        - tpacpi: /proc/acpi/ibm/thermal
        levels:
        ${levelsYaml}
    '';

    thinkfanAutoYaml = mkThinkfanYaml "auto" ''
        - - 0
          - 0
          - 48
        - - 1
          - 44
          - 54
        - - 2
          - 50
          - 60
        - - 3
          - 56
          - 65
        - - 6
          - 60
          - 72
        - - 7
          - 68
          - 85
        - - level disengaged
          - 80
          - 255
    '';

    thinkfanQuietYaml = mkThinkfanYaml "quiet" ''
        - - 0
          - 0
          - 68
        - - 1
          - 62
          - 76
        - - 3
          - 72
          - 84
        - - 7
          - 80
          - 90
        - - level disengaged
          - 87
          - 255
    '';

    thinkfanMaxYaml = mkThinkfanYaml "max" ''
        - - level disengaged
          - 0
          - 255
    '';

    mkThinkfanSwitch = mode: yamlFile: pkgs.writeShellScript "switch-thinkfan-${mode}" ''
        set -e
        ln -sfn "${yamlFile}" /run/thinkfan-active.yaml
        printf "%s\n" "${mode}" > /run/fan-mode
        chmod 0644 /run/fan-mode
        /run/current-system/sw/bin/systemctl restart thinkfan.service
    '';

    # Re-apply active undervolt power/thermal/turbo profile on wake from sleep
    restoreUndervoltProfile = pkgs.writeShellScript "restore-undervolt-profile" ''
        mode=$(cat /run/power-mode 2>/dev/null || echo "")
        if [ -z "$mode" ]; then
            ac=$(cat /sys/class/power_supply/AC/online 2>/dev/null || echo 1)
            [ "$ac" = "0" ] && mode="saver" || mode="balanced"
        fi
        case "$mode" in
            performance|balanced|saver)
                /run/current-system/sw/bin/systemctl start "undervolt-$mode.service"
                ;;
            *)
                /run/current-system/sw/bin/systemctl start undervolt-balanced.service
                ;;
        esac
    '';
in
{
    services = {

        flatpak.enable = true;

        printing.enable = false; # CUPS

        avahi = {
            enable = false;
            # nssmdns4 = true;
            # openFirewall = true;
        };

        libinput.enable = true; # touchpad

        openssh.enable = true;

        fprintd.enable = true; # fingerprint

        # Enable Tor SOCKS5 client (127.0.0.1:9050), Transparent TCP Proxy (127.0.0.1:9040),
        # and local UDP DNSPort (127.0.0.1:9053) for .onion AutomapHostsOnResolve,
        # but do NOT start on boot (systemd.services.tor.wantedBy is cleared below)
        tor = {
            enable = true;
            client.enable = true;
            settings = {
                TransPort = [ 9040 ];
                DNSPort = [ 9053 ];
                VirtualAddrNetworkIPv4 = "10.192.0.0/10";
                AutomapHostsOnResolve = true;
            };
        };

        displayManager.sddm.enable = true;
        displayManager.sddm.wayland.enable = true;

        power-profiles-daemon = {
            enable = false;
        };

        tlp = {
            enable = true;
            settings = {
                START_CHARGE_THRESH_BAT0 = 75;
                STOP_CHARGE_THRESH_BAT0 = 85;

                # cap power/thermals on battery only; AC keeps full turbo/115W
                CPU_SCALING_GOVERNOR_ON_AC = "powersave";
                CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
                CPU_BOOST_ON_AC = 1;
                CPU_BOOST_ON_BAT = 0;
                CPU_HWP_DYN_BOOST_ON_AC = 1;
                CPU_HWP_DYN_BOOST_ON_BAT = 0;
                PLATFORM_PROFILE_ON_AC = "balanced";
                PLATFORM_PROFILE_ON_BAT = "low-power";
                CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
                CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
                PCIE_ASPM_ON_AC = "default";
                PCIE_ASPM_ON_BAT = "powersupersave";
                RUNTIME_PM_ON_AC = "auto";
                RUNTIME_PM_ON_BAT = "auto";
                USB_AUTOSUSPEND = 1;
                WIFI_PWR_ON_AC = "off";
                WIFI_PWR_ON_BAT = "on";
                SOUND_POWER_SAVE_ON_AC = 1;
                SOUND_POWER_SAVE_ON_BAT = 1;
                SOUND_POWER_SAVE_CONTROLLER = "Y";
                NMI_WATCHDOG = 0;

                # Cap Intel Iris Xe iGPU boost on battery (RPn=100, RP1=300, RP0=1400)
                INTEL_GPU_MIN_FREQ_ON_AC = 100;
                INTEL_GPU_MAX_FREQ_ON_AC = 1400;
                INTEL_GPU_BOOST_FREQ_ON_AC = 1400;
                INTEL_GPU_MIN_FREQ_ON_BAT = 100;
                INTEL_GPU_MAX_FREQ_ON_BAT = 600;
                INTEL_GPU_BOOST_FREQ_ON_BAT = 600;

                # TLP's MAX_LOST_WORK_SECS_ON_* sets vm.dirty_writeback_centisecs,
                # vm.dirty_expire_centisecs, and filesystem commit intervals so the
                # NVMe can batch writes and stay in deep APST sleep longer
                MAX_LOST_WORK_SECS_ON_AC = 15;
                MAX_LOST_WORK_SECS_ON_BAT = 60;
            };
        };

        thinkfan = {
            enable = true;

            sensors = [
                {
                    type = "tpacpi";
                    query = "/proc/acpi/ibm/thermal";
                }
            ];

            fans = [
                {
                    type = "tpacpi";
                    query = "/proc/acpi/ibm/fan";
                }
            ];

            # Default `auto` curve (runtime-switchable via thinkfan-{auto,quiet,max}.service)
            # [fan level, step-down temperature, step-up temperature]
            levels = [
                [
                    0
                    0
                    48
                ]
                [
                    1
                    44
                    54
                ]
                [
                    2
                    50
                    60
                ]
                [
                    3
                    56
                    65
                ]
                [
                    6
                    60
                    72
                ]
                [
                    7
                    68
                    85
                ]
                [
                    "level disengaged"
                    80
                    255
                ] # disengaged = FLOOR IT
            ];
        };

        udev.extraRules = ''
            ACTION=="add|bind", SUBSYSTEM=="platform", DRIVER=="thinkpad_acpi", RUN+="${pkgs.coreutils}/bin/chgrp fan_ctl /proc/acpi/ibm/fan", RUN+="${pkgs.coreutils}/bin/chmod 0664 /proc/acpi/ibm/fan"
            SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1915", ATTRS{idProduct}=="520a", MODE="0660", GROUP="input"
        '';

        undervolt = {
            # undervolting / RAPL power limits for intel cpus
            # Note: leave `turbo` unset here so boot/resume doesn't pass `--turbo 1` (which
            # disables Intel Turbo Boost on AC); TLP and undervolt-{saver,balanced,performance}
            # manage turbo & PROCHOT dynamically.
            enable = true;

            # Keep PROCHOT above normal idle temps so it doesn't cause a thermal
            # interrupt storm across all 20 threads while RAPL caps power smoothly
            tempBat = 65; # target temp on battery
            temp = 85;

            # fuck u intel, just make better cpus
            # coreOffset = -150;
            # uncoreOffset = -150;

            gpuOffset = 0; # integrated GPU?

            # PL1 (sustained) / PL2 (boost) power limits, in watts
            p1 = {
                limit = 35;
                window = 28;
            };
            p2 = {
                limit = 65;
                window = 0.002;
            };
        };
    };

    # let power_ctl group write the ACPI platform-profile knob for the waybar power toggle,
    # and initialize the active ThinkFan profile symlink (/run/thinkfan-active.yaml) at boot
    systemd.tmpfiles.rules = [
        "z /sys/firmware/acpi/platform_profile 0664 root power_ctl -"
        "L /run/thinkfan-active.yaml - - - - ${thinkfanAutoYaml}"
        "f /run/fan-mode 0644 root root - auto"
    ];

    systemd.services = {
        # Point thinkfan at the runtime-switchable profile symlink (/run/thinkfan-active.yaml)
        thinkfan.environment.THINKFAN_ARGS = lib.mkForce "-b0 -c /run/thinkfan-active.yaml";

        thinkfan-auto = {
            description = "ThinkFan profile: auto";
            serviceConfig = {
                Type = "oneshot";
                ExecStart = mkThinkfanSwitch "auto" thinkfanAutoYaml;
            };
        };
        thinkfan-quiet = {
            description = "ThinkFan profile: quiet";
            serviceConfig = {
                Type = "oneshot";
                ExecStart = mkThinkfanSwitch "quiet" thinkfanQuietYaml;
            };
        };
        thinkfan-max = {
            description = "ThinkFan profile: max (disengaged)";
            serviceConfig = {
                Type = "oneshot";
                ExecStart = mkThinkfanSwitch "max" thinkfanMaxYaml;
            };
        };

        # Runtime-switchable P1/P2 (PL1/PL2) + PROCHOT + Turbo profiles, triggered by
        # power-*.sh via `sudo systemctl start undervolt-<mode>.service` (see modules/security.nix)
        undervolt-performance = {
            description = "Undervolt profile: performance";
            serviceConfig = {
                Type = "oneshot";
                ExecStart = pkgs.writeShellScript "undervolt-performance" ''
                    printf "performance\n" > /run/power-mode
                    chmod 0644 /run/power-mode
                    exec ${pkgs.undervolt}/bin/undervolt --turbo 0 --temp 85 --power-limit-long 45 28 --power-limit-short 115 0.002
                '';
            };
        };
        undervolt-balanced = {
            description = "Undervolt profile: balanced";
            serviceConfig = {
                Type = "oneshot";
                ExecStart = pkgs.writeShellScript "undervolt-balanced" ''
                    printf "balanced\n" > /run/power-mode
                    chmod 0644 /run/power-mode
                    exec ${pkgs.undervolt}/bin/undervolt --turbo 0 --temp 85 --temp-bat 65 --power-limit-long 35 28 --power-limit-short 65 0.002
                '';
            };
        };
        undervolt-saver = {
            description = "Undervolt profile: saver";
            serviceConfig = {
                Type = "oneshot";
                ExecStart = pkgs.writeShellScript "undervolt-saver" ''
                    printf "saver\n" > /run/power-mode
                    chmod 0644 /run/power-mode
                    exec ${pkgs.undervolt}/bin/undervolt --turbo 1 --temp 65 --power-limit-long 20 28 --power-limit-short 35 0.002
                '';
            };
        };

        # Re-apply active profile on resume instead of clobbering turbo/limits with boot defaults
        undervolt-sleep.serviceConfig.ExecStop = lib.mkForce restoreUndervoltProfile;

        # Keep Tor stopped at boot to save battery; started on-demand by dns-proxy-tor.service
        tor.wantedBy = lib.mkForce [ ];

        # Daemon units for Direct DoH vs Tor-routed DoH + .onion DNSPort forwarding
        dnscrypt-proxy-direct = {
            description = "DNSCrypt-Proxy (Direct Cloudflare DoH)";
            conflicts = [ "dnscrypt-proxy-tor.service" ];
            serviceConfig = {
                Type = "simple";
                DynamicUser = true;
                StateDirectory = "dnscrypt-proxy";
                AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
                CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
                Restart = "on-failure";
                RestartSec = "2s";
                ExecStart = "${pkgs.dnscrypt-proxy}/bin/dnscrypt-proxy -config ${dnscryptDirectConf}";
            };
        };

        dnscrypt-proxy-tor = {
            description = "DNSCrypt-Proxy (Cloudflare DoH over Tor + .onion DNSPort)";
            requires = [ "tor.service" ];
            after = [ "tor.service" ];
            conflicts = [ "dnscrypt-proxy-direct.service" ];
            serviceConfig = {
                Type = "simple";
                DynamicUser = true;
                StateDirectory = "dnscrypt-proxy";
                AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
                CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
                Restart = "on-failure";
                RestartSec = "2s";
                ExecStart = "${pkgs.dnscrypt-proxy}/bin/dnscrypt-proxy -config ${dnscryptTorConf}";
            };
        };

        # Oneshot mode-switching targets invoked by Waybar (sudoers in modules/security.nix)
        dns-proxy-off = {
            description = "DNS Proxy Mode: Off (Restore NetworkManager DHCP DNS & Direct Routing)";
            serviceConfig = {
                Type = "oneshot";
                ExecStart = pkgs.writeShellScript "dns-proxy-off" ''
                    ${stopTorTransProxy}
                    ${stopWarpTunnel}
                    /run/current-system/sw/bin/resolvconf -d lo.dnscrypt -f || true
                    /run/current-system/sw/bin/systemctl stop dnscrypt-proxy-direct.service dnscrypt-proxy-tor.service tor.service || true
                '';
            };
        };

        dns-proxy-direct = {
            description = "DNS Proxy Mode: Direct (Cloudflare DoH on 127.0.0.1, Direct IP)";
            serviceConfig = {
                Type = "oneshot";
                ExecStart = pkgs.writeShellScript "dns-proxy-direct" ''
                    ${stopTorTransProxy}
                    ${stopWarpTunnel}
                    /run/current-system/sw/bin/systemctl stop dnscrypt-proxy-tor.service tor.service || true
                    /run/current-system/sw/bin/systemctl start dnscrypt-proxy-direct.service
                    ${waitDnsPort53}
                    printf "nameserver 127.0.0.1\n" | /run/current-system/sw/bin/resolvconf -a lo.dnscrypt -x
                '';
            };
        };

        dns-proxy-warp = {
            description = "DNS Proxy Mode: Cloudflare WARP (WireGuard Full Tunnel + Cloudflare DoH)";
            serviceConfig = {
                Type = "oneshot";
                ExecStart = pkgs.writeShellScript "dns-proxy-warp" ''
                    ${stopTorTransProxy}
                    /run/current-system/sw/bin/systemctl stop dnscrypt-proxy-tor.service tor.service || true
                    /run/current-system/sw/bin/systemctl start dnscrypt-proxy-direct.service
                    ${waitDnsPort53}
                    printf "nameserver 127.0.0.1\n" | /run/current-system/sw/bin/resolvconf -a lo.dnscrypt -x
                    ${startWarpTunnel}
                '';
            };
        };

        dns-proxy-tor = {
            description = "DNS Proxy Mode: Tor (Transparent TCP Proxy + .onion DNSPort + Cloudflare DoH)";
            serviceConfig = {
                Type = "oneshot";
                ExecStart = pkgs.writeShellScript "dns-proxy-tor" ''
                    ${stopWarpTunnel}
                    /run/current-system/sw/bin/systemctl stop dnscrypt-proxy-direct.service || true
                    /run/current-system/sw/bin/systemctl start tor.service
                    # Wait for Tor to bind TransPort (127.0.0.1:9040 = 0100007F:2350)
                    for _ in $(seq 1 50); do
                        if grep -q "0100007F:2350" /proc/net/tcp 2>/dev/null; then
                            break
                        fi
                        sleep 0.1
                    done
                    ${startTorTransProxy}
                    /run/current-system/sw/bin/systemctl start dnscrypt-proxy-tor.service
                    ${waitDnsPort53}
                    printf "nameserver 127.0.0.1\n" | /run/current-system/sw/bin/resolvconf -a lo.dnscrypt -x
                '';
            };
        };
    };
}
