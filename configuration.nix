{
    config,
    pkgs,
    lib,
    ...
}:

{
    imports = [
        "./modules"
    ];

    # Enable the X11 windowing system.
    # You can disable this if you're only using the Wayland session.
    services.xserver.enable = true;

    services.displayManager.sddm.enable = true;
    services.desktopManager.plasma6.enable = true;

    # Configure keymap in X11
    services.xserver.xkb = {
        layout = "us";
        variant = "";
    };

    nixpkgs.config.allowUnfree = true;

    nix.settings.experimental-features = [
        "nix-command"
        "flakes"
    ];

    # Smallest supported version of NixOS
    system.stateVersion = "26.05";
}
