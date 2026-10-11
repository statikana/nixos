{ ... }: {
    # https://wiki.nixos.org/wiki/Hyprland#Display_Manager_Support
    # make sure you're on
    wayland.windowManager.hyprland = {
        # USWM and xserver settings are in ../modules/programs.nix

        enable = true;
        xwayland.enable = true;
        systemd.enable = false; # handled by uwsm
        configType = "lua";

        extraLuaFiles = {
            appearance = ./hyprland-config/appearance.lua;
            binds = ./hyprland-config/binds.lua;
            display = ./hyprland-config/display.lua;
            input = ./hyprland-config/input.lua;
            permissions = ./hyprland-config/permissions.lua;
            programs = ./hyprland-config/programs.lua;
        };
        plugins = [ ];

        # don't install again
        package = null;
        portalPackage = null;
    };
}
