{ ... }: {
    services.hyprpaper = {
        enable = true;
        settings = {
            splash = true;
            wallpaper = [
                {
                    fit_mode = "cover";
                    monitor = "eDP-1";
                    path = "/share/wallpapers/buttons.png";
                }
            ];
        };
    };
}
