{ ... }: {
    services.flatpak.enable = true;

    services.printing.enable = true;  # CUPS

    services.libinput.enable = true; # touchpad

    services.openssh.enable = true;

    services.fprintd.enable = true; # fingerprint
}