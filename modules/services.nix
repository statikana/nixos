{ pkgs, ... }: {
    services = {

        flatpak.enable = true;

        printing.enable = true; # CUPS

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
        desktopManager.plasma6.enable = true; # backup

        power-profiles-daemon = {
            enable = false;
        };
        
        tlp = {
            enable = true;
            settings = {
                START_CHARGE_THRESH_BAT0 = 70;
                STOP_CHARGE_THRESH_BAT0 = 85;
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
                [ "level auto" 80 32767 ]
            ];
        };

        udev.extraRules = ''ACTION=="add|bind", SUBSYSTEM=="platform", DRIVER=="thinkpad_acpi", RUN+="${pkgs.coreutils}/bin/chgrp fan_ctl /proc/acpi/ibm/fan", RUN+="${pkgs.coreutils}/bin/chmod 0664 /proc/acpi/ibm/fan"'';
    };
}
