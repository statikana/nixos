{
    config,
    pkgs,
    lib,
    ...
}:
let
    home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
in
{
    imports = [
        "/home/ryan/nixos/modules"
        "${home-manager}/nixos"
    ];

    home-manager.users."ryan" = import "/home/ryan/nixos/home-config/ryan";

    nixpkgs.config.allowUnfree = true;

    nix.settings.experimental-features = [
        "nix-command"
        "flakes"
    ];

    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    # Smallest supported version of NixOS, don't change
    system.stateVersion = "26.05";
}
