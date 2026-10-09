{ ... }: {
    programs.nix-ld.enable = true;
    
    programs.firefox.enable = true;
    programs.steam.enable = true;

    # hyprland is managed in ./hyprland.nix
    # programs.hyprland.enabled = true;
}