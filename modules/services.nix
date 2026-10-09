{ ... }: {
    services.flatpak.enable = true;

    services.printing.enable = true; # CUPS

    services.libinput.enable = true; # touchpad

    services.openssh.enable = true;

    services.fprintd.enable = true; # fingerprint

    services.dnscrypt-proxy = {
        enable = true;
        settings = {
            server_names = ["cloudflare"];
            proxy = "socks5://127.0.0.1:9050";
            force_tcp = true;
        };
    };
}
