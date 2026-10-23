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
        wirelesstools
        iw

        hyprshade # idrk
        wev # wayland events
        playerctl # audio stuff
        pavucontrol #... other audio stuff?
        networkmanagerapplet # NM GUI
        hyprpicker # colors
        cliphist
        blueman
        pulseaudio
        peazip
        impala
        bluetuith # TUI bluetooth manager, replaces blueman-manager on waybar left-click
        wiremix # TUI pipewire mixer, replaces pavucontrol on waybar left-click
        nerd-fonts.jetbrains-mono
    ];
}
