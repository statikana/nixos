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
            # https://edc.intel.com/content/www/us/en/design/ipla/software-development-platforms/client/platforms/alder-lake-desktop/12th-generation-intel-core-processors-datasheet-volume-1-of-2/package-power-control/
            turbo = 1;

            tempBat = 40; # target temp
            tempAc = 60;

            coreOffset = -150;
            uncoreOffset = -150;

            gpuOffset = 0;  # integrated GPU?

            
        };
    };  
}
