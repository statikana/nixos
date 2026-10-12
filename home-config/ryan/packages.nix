{ pkgs, ... }: {
    home.packages = with pkgs; [
        hyprpolkitagent # policy / perms
        wl-clipboard # CLI copy paste
        hyprshot # screenshots
        waybar # upper bar
        brightnessctl
        hyprpaper # wallpapers
        wofi # launcher

        lm_sensors
        fanctl

        hyprshade # idrk
        wev # wayland events
        playerctl # audio stuff
        pavucontrol #... other audio stuff?
        networkmanagerapplet # NM GUI
        hyprpicker # colors
        ffmpeg
        cliphist
        blueman
        pulseaudio

        nerd-fonts.jetbrains-mono
    ];
}
