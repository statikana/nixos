{
    config,
    pkgs,
    lib,
    ...
}:
{
    imports = [
        ./modules
        ./hardware-configuration.nix
    ];

    home-manager.users."ryan" = import ./home-config/ryan;
    home-manager.useGlobalPkgs = true;

    nixpkgs.config.allowUnfree = true;

    nix.settings.experimental-features = [
        "nix-command"
        "flakes"
    ];

    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    # Smallest supported version of NixOS, don't change
    system.stateVersion = "26.05";
}
