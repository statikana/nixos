{ ... }: {
    programs.waybar = {
        enable = true;
    };

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
