{ pkgs, ... }: {
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

        dnscrypt-proxy = {
            enable = false;
            settings = {
                server_names = [ "cloudflare" ];
                proxy = "socks5://127.0.0.1:9050";
                force_tcp = true;
            };
        };

        tor.enable = false;

        displayManager.sddm.enable = true;
        displayManager.sddm.wayland.enable = true;

        power-profiles-daemon = {
            enable = false;
        };
        
        tlp = {
            enable = true;
            settings = {
                START_CHARGE_THRESH_BAT0 = 85;
                STOP_CHARGE_THRESH_BAT0 = 85;

                # cap power/thermals on battery only; AC keeps full turbo/115W
                CPU_BOOST_ON_BAT = 0;
                PLATFORM_PROFILE_ON_BAT = "low-power";
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
                [ 2 0 52 ]
                [ 3 52 63 ]
                [ 6 56 65 ]
                [ 7 60 85 ]
                [ "level disengaged" 80 255 ] # disengaged = FLOOR IT
            ];
        };

        udev.extraRules = ''ACTION=="add|bind", SUBSYSTEM=="platform", DRIVER=="thinkpad_acpi", RUN+="${pkgs.coreutils}/bin/chgrp fan_ctl /proc/acpi/ibm/fan", RUN+="${pkgs.coreutils}/bin/chmod 0664 /proc/acpi/ibm/fan"'';

        undervolt = {  # undervolting for intel cpus
            enable = true;
            # https://edc.intel.com/content/www/us/en/design/ipla/software-development-platforms/client/platforms/alder-lake-desktop/12th-generation-intel-core-processors-datasheet-volume-1-of-2/package-power-control/
            turbo = 1;

            # tempAc is in the docs but is depracated. temp coveres AC (and Battery, unless tempBat is also set).
            tempBat = 40; # target temp
            temp = 45;
            
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
                RemainAfterExit = true;
                ExecStart = ''${pkgs.undervolt}/bin/undervolt --turbo 0 --power-limit-long "45 28" --power-limit-short "115 0.002"'';
            };
        };
        undervolt-balanced = {
            description = "Undervolt profile: balanced";
            serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = ''${pkgs.undervolt}/bin/undervolt --turbo 0 --power-limit-long "35 28" --power-limit-short "65 0.002"'';
            };
        };
        undervolt-saver = {
            description = "Undervolt profile: saver";
            serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = ''${pkgs.undervolt}/bin/undervolt --turbo 1 --power-limit-long "20 28" --power-limit-short "35 0.002"'';
            };
        };
    };
}
