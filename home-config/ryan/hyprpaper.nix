{ ... }: {
    services.hyprpaper = {
        enable = true;
        settings = {
            splash = true;
            wallpaper = [
                {
                    fit_mode = "cover";
                    monitor = "";
                    path = "/home/ryan/Downloads/glassy_bands.png";
                }
            ];
        };
    };
}
