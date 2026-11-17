{ pkgs, lib, ... }:
let
    flyoutPython = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);
    flyoutTypelibs = lib.makeSearchPath "lib/girepository-1.0" [
        pkgs.gtk4
        pkgs.gtk4-layer-shell
        pkgs.gobject-introspection
        pkgs.pango.out
        pkgs.gdk-pixbuf
        pkgs.harfbuzz
        pkgs.graphene
        pkgs.glib.out
    ];
    waybarFlyoutPython = pkgs.writeShellScriptBin "waybar-flyout-python" ''
        export LD_PRELOAD="${pkgs.gtk4-layer-shell}/lib/libgtk4-layer-shell.so''${LD_PRELOAD:+:$LD_PRELOAD}"
        export LD_LIBRARY_PATH="${pkgs.gtk4-layer-shell}/lib:${pkgs.gtk4}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        export GI_TYPELIB_PATH="${flyoutTypelibs}''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
        exec "${flyoutPython}/bin/python3" "$@"
    '';
in
{
    programs.waybar = {
        enable = true;
    };

    home.packages = [
        waybarFlyoutPython
    ];

    # drives signal 8 to waybar's workspace buttons on actual workspace change,
    # replacing the old 0.3s poll (see scripts/workspace/workspace-listener.sh)
    systemd.user.services.workspace-listener = {
        Unit = {
            Description = "Signal waybar on Hyprland workspace change";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
        };
        Service = {
            ExecStart = "/home/ryan/nixos/home-config/ryan/scripts/workspace/workspace-listener.sh";
            Restart = "on-failure";
            RestartSec = 2;
        };
        Install = {
            WantedBy = [ "graphical-session.target" ];
        };
    };

    # 165Hz on AC, 60Hz on battery -- see scripts/power/refresh-rate-listener.sh
    systemd.user.services.refresh-rate-listener = {
        Unit = {
            Description = "Switch display refresh rate on AC/battery change";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
        };
        Service = {
            ExecStart = "/home/ryan/nixos/home-config/ryan/scripts/power/refresh-rate-listener.sh";
            Restart = "on-failure";
            RestartSec = 2;
        };
        Install = {
            WantedBy = [ "graphical-session.target" ];
        };
    };
}
