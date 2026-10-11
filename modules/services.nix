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
    };
}
