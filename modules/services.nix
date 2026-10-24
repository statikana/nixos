{ pkgs, lib, ... }:
let
    # Base DNSCrypt-Proxy configuration using Cloudflare's static DoH stamp so
    # it starts answering queries on 127.0.0.1:53 immediately without needing an
    # unencrypted bootstrap fetch of public-resolvers.md first.
    dnscryptBaseToml = ''
        listen_addresses = ["127.0.0.1:53", "[::1]:53"]
        server_names = ["cloudflare"]
        ipv4_servers = true
        ipv6_servers = false
        dnscrypt_servers = true
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

    dnscryptCloudflareStatic = ''
        [static.cloudflare]
        stamp = "sdns://AgcAAAAAAAAABzEuMS4xLjGgENk8mGSlIfMGXMOlIlCcKvq7AVgcrZxtjon911-ep0cg63Ul-I8NlFj4GplQGb_TTLiczclX57DvMV8Q-JdjgRgSZG5zLmNsb3VkZmxhcmUuY29tCi9kbnMtcXVlcnk"
    '';

    dnscryptDirectConf = pkgs.writeText "dnscrypt-proxy-direct.toml" ''
        ${dnscryptBaseToml}
        timeout = 5000
        keepalive = 30

        ${dnscryptCloudflareStatic}
    '';

    dnscryptTorConf = pkgs.writeText "dnscrypt-proxy-tor.toml" ''
        ${dnscryptBaseToml}
        proxy = "socks5://127.0.0.1:9050"
        force_tcp = true
        timeout = 10000
        keepalive = 30

        ${dnscryptCloudflareStatic}
    '';

    # Helper script to remove Tor transparent proxy iptables/ip6tables chains
    stopTorTransProxy = pkgs.writeShellScript "stop-tor-transproxy" ''
        ${pkgs.iptables}/bin/iptables -t nat -D OUTPUT -p tcp -j TOR_PROXY 2>/dev/null || true
        ${pkgs.iptables}/bin/iptables -t nat -F TOR_PROXY 2>/dev/null || true
        ${pkgs.iptables}/bin/iptables -t nat -X TOR_PROXY 2>/dev/null || true

        ${pkgs.iptables}/bin/iptables -t filter -D OUTPUT -j TOR_FILTER 2>/dev/null || true
        ${pkgs.iptables}/bin/iptables -t filter -F TOR_FILTER 2>/dev/null || true
        ${pkgs.iptables}/bin/iptables -t filter -X TOR_FILTER 2>/dev/null || true

        ${pkgs.iptables}/bin/ip6tables -t filter -D OUTPUT -j TOR_FILTER6 2>/dev/null || true
        ${pkgs.iptables}/bin/ip6tables -t filter -F TOR_FILTER6 2>/dev/null || true
        ${pkgs.iptables}/bin/ip6tables -t filter -X TOR_FILTER6 2>/dev/null || true
    '';

    # Helper script to enable Tor transparent TCP proxy (TransPort 9040) + block UDP/IPv6 leaks
    startTorTransProxy = pkgs.writeShellScript "start-tor-transproxy" ''
        ${stopTorTransProxy}

        # 1. NAT chain: redirect outbound TCP SYN packets to Tor TransPort (127.0.0.1:9040)
        ${pkgs.iptables}/bin/iptables -t nat -N TOR_PROXY
        ${pkgs.iptables}/bin/iptables -t nat -A TOR_PROXY -m owner --uid-owner tor -j RETURN
        for net in 127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 100.64.0.0/10 169.254.0.0/16 224.0.0.0/4 240.0.0.0/4; do
            ${pkgs.iptables}/bin/iptables -t nat -A TOR_PROXY -d "$net" -j RETURN
        done
        ${pkgs.iptables}/bin/iptables -t nat -A TOR_PROXY -p tcp --syn -j REDIRECT --to-ports 9040
        ${pkgs.iptables}/bin/iptables -t nat -A OUTPUT -p tcp -j TOR_PROXY

        # 2. Filter chain: reject non-LAN outbound UDP (e.g. QUIC UDP:443) so browsers
        # immediately fall back to TCP:443 through Tor instead of leaking real IP
        ${pkgs.iptables}/bin/iptables -t filter -N TOR_FILTER
        ${pkgs.iptables}/bin/iptables -t filter -A TOR_FILTER -m owner --uid-owner tor -j RETURN
        for net in 127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 100.64.0.0/10 169.254.0.0/16 224.0.0.0/4 255.255.255.255/32; do
            ${pkgs.iptables}/bin/iptables -t filter -A TOR_FILTER -d "$net" -j RETURN
        done
        ${pkgs.iptables}/bin/iptables -t filter -A TOR_FILTER -p udp -j REJECT --reject-with icmp-port-unreachable
        ${pkgs.iptables}/bin/iptables -t filter -A OUTPUT -j TOR_FILTER

        # 3. IPv6 filter chain: reject non-local IPv6 traffic so dual-stack connections
        # use IPv4 TCP through Tor TransPort 9040 instead of leaking IPv6 address
        ${pkgs.iptables}/bin/ip6tables -t filter -N TOR_FILTER6
        ${pkgs.iptables}/bin/ip6tables -t filter -A TOR_FILTER6 -m owner --uid-owner tor -j RETURN
        ${pkgs.iptables}/bin/ip6tables -t filter -A TOR_FILTER6 -d ::1/128 -j RETURN
        ${pkgs.iptables}/bin/ip6tables -t filter -A TOR_FILTER6 -d fe80::/10 -j RETURN
        ${pkgs.iptables}/bin/ip6tables -t filter -A TOR_FILTER6 -j REJECT --reject-with icmp6-adm-prohibited
        ${pkgs.iptables}/bin/ip6tables -t filter -A OUTPUT -j TOR_FILTER6
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

        # Managed on-demand by Waybar's DNS proxy switch (dns-proxy-{off,direct,tor}.service)
        # so port 53 / /etc/resolv.conf are not permanently hijacked at boot
        dnscrypt-proxy = {
            enable = false;
            settings = {
                server_names = [ "cloudflare" ];
                proxy = "socks5://127.0.0.1:9050";
                force_tcp = true;
            };
        };

        # Enable Tor SOCKS5 client (127.0.0.1:9050) + Transparent TCP Proxy (127.0.0.1:9040),
        # but do NOT start on boot (systemd.services.tor.wantedBy is cleared below)
        tor = {
            enable = true;
            client.enable = true;
            settings = {
                TransPort = [ 9040 ];
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

                # TLP'sMAX_LOST_WORK_SECS_ON_* sets vm.dirty_writeback_centisecs,
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

            # [fan level, step-down temperature, step-up temperature]
            levels = [
                [ 0 0 48 ]
                [ 1 44 54 ]
                [ 2 50 60 ]
                [ 3 56 65 ]
                [ 6 60 72 ]
                [ 7 68 85 ]
                [ "level disengaged" 80 255 ] # disengaged = FLOOR IT
            ];
        };

        udev.extraRules = ''ACTION=="add|bind", SUBSYSTEM=="platform", DRIVER=="thinkpad_acpi", RUN+="${pkgs.coreutils}/bin/chgrp fan_ctl /proc/acpi/ibm/fan", RUN+="${pkgs.coreutils}/bin/chmod 0664 /proc/acpi/ibm/fan"'';

        undervolt = {  # undervolting / RAPL power limits for intel cpus
            enable = true;
            # https://edc.intel.com/content/www/us/en/design/ipla/software-development-platforms/client/platforms/alder-lake-desktop/12th-generation-intel-core-processors-datasheet-volume-1-of-2/package-power-control/
            turbo = 1;

            # Keep PROCHOT above normal idle temps so it doesn't cause a thermal
            # interrupt storm across all 20 threads while RAPL caps power smoothly
            tempBat = 65; # target temp on battery
            temp = 85;
            
            # fuck u intel, just make better cpus
            # coreOffset = -150;
            # uncoreOffset = -150;

            gpuOffset = 0;  # integrated GPU?

            # PL1 (sustained) / PL2 (boost) power limits, in watts
            p1 = { limit = 35; window = 28; };
            p2 = { limit = 65; window = 0.002; };

        };
    };

    # let power_ctl group write the ACPI platform-profile knob for the waybar power toggle
    # (performance / balanced / low-power), without needing sudo at runtime
    systemd.tmpfiles.rules = [
        "z /sys/firmware/acpi/platform_profile 0664 root power_ctl -"
    ];

    # runtime-switchable P1/P2 (PL1/PL2) profiles, triggered by the power-*.sh
    # scripts via `sudo systemctl start undervolt-<mode>.service` (see modules/security.nix)
    systemd.services = {
        undervolt-performance = {
            description = "Undervolt profile: performance";
            serviceConfig = {
                Type = "oneshot";
                ExecStart = ''${pkgs.undervolt}/bin/undervolt --turbo 0 --power-limit-long 45 28 --power-limit-short 115 0.002'';
            };
        };
        undervolt-balanced = {
            description = "Undervolt profile: balanced";
            serviceConfig = {
                Type = "oneshot";
                ExecStart = ''${pkgs.undervolt}/bin/undervolt --turbo 0 --power-limit-long 35 28 --power-limit-short 65 0.002'';
            };
        };
        undervolt-saver = {
            description = "Undervolt profile: saver";
            serviceConfig = {
                Type = "oneshot";
                ExecStart = ''${pkgs.undervolt}/bin/undervolt --turbo 1 --power-limit-long 20 28 --power-limit-short 35 0.002'';
            };
        };

        # Keep Tor stopped at boot to save battery; started on-demand by dns-proxy-tor.service
        tor.wantedBy = lib.mkForce [ ];

        # Daemon units for Direct DoH vs Tor-routed DoH
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
            description = "DNSCrypt-Proxy (Cloudflare DoH over Tor SOCKS5)";
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
                    /run/current-system/sw/bin/resolvconf -d lo.dnscrypt -f || true
                    /run/current-system/sw/bin/systemctl stop dnscrypt-proxy-direct.service dnscrypt-proxy-tor.service tor.service || true
                    echo "off" > /run/dns-proxy-mode
                    chmod 0644 /run/dns-proxy-mode
                '';
            };
        };

        dns-proxy-direct = {
            description = "DNS Proxy Mode: Direct (Cloudflare DoH on 127.0.0.1, Direct IP)";
            serviceConfig = {
                Type = "oneshot";
                ExecStart = pkgs.writeShellScript "dns-proxy-direct" ''
                    ${stopTorTransProxy}
                    /run/current-system/sw/bin/systemctl stop dnscrypt-proxy-tor.service tor.service || true
                    /run/current-system/sw/bin/systemctl start dnscrypt-proxy-direct.service
                    printf "nameserver 127.0.0.1\n" | /run/current-system/sw/bin/resolvconf -a lo.dnscrypt -x
                    echo "direct" > /run/dns-proxy-mode
                    chmod 0644 /run/dns-proxy-mode
                '';
            };
        };

        dns-proxy-tor = {
            description = "DNS Proxy Mode: Tor (Transparent TCP Proxy + Cloudflare DoH over Tor)";
            serviceConfig = {
                Type = "oneshot";
                ExecStart = pkgs.writeShellScript "dns-proxy-tor" ''
                    /run/current-system/sw/bin/systemctl stop dnscrypt-proxy-direct.service || true
                    /run/current-system/sw/bin/systemctl start tor.service dnscrypt-proxy-tor.service
                    printf "nameserver 127.0.0.1\n" | /run/current-system/sw/bin/resolvconf -a lo.dnscrypt -x
                    ${startTorTransProxy}
                    echo "tor" > /run/dns-proxy-mode
                    chmod 0644 /run/dns-proxy-mode
                '';
            };
        };
    };
}
