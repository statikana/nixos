{ ... }: {
    nix.gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 10d";
    };

    nix.settings.auto-optimise-store = true;

    boot.loader.systemd-boot.configurationLimit = 10;
}
