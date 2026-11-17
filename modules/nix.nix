{ ... }: {
    nix.gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 10d";
    };

    nix.settings.auto-optimise-store = true;
    nix.settings.extra-substituters = [ "https://danielbodart.cachix.org" ];
    nix.settings.extra-trusted-public-keys = [
        "danielbodart.cachix.org-1:751qv4GxLFJCThWMEw1WL6kUqY0DpF6oqPqsLKnnEwU="
    ];

    boot.loader.systemd-boot.configurationLimit = 10;
}
