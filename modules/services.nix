{ ... }: {
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
                START_CHARGE_THRESH_BAT0 = 40;
                STOP_CHARGE_THRESH_BAT0 = 80;
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
                [ 0 0 55 ]
                [ 1 48 60 ]
                [ 2 50 61 ]
                [ 3 52 63 ]
                [ 6 56 65 ]
                [ 7 60 85 ]
                [ "level auto" 80 32767 ]
            ];
        };
    };
}
