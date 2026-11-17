{
    config,
    pkgs,
    lib,
    inputs,
    ...
}:{
    imports = [
        ./modules
        ./hardware-configuration.nix
    ];

    home-manager.users."ryan" = import ./home-config/ryan;
    home-manager.useGlobalPkgs = true;
    home-manager.extraSpecialArgs = { inherit inputs; };

    nixpkgs.config = {
        allowUnfree = true;
        permittedInsecurePackages = ["ventoy-1.1.18"];
    };

    nix.settings.experimental-features = [
        "nix-command"
        "flakes"
    ];

    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    # Smallest supported version of NixOS, don't change
    system.stateVersion = "26.05";
}
