{ pkgs, ... }:
{
    services.hyprpolkitagent.enable = true;

    home.packages = with pkgs; [
        wl-clipboard # CLI copy paste
        hyprshot # screenshots
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
        pavucontrol # GUI audio fallback
        hyprpicker # colors
        cliphist
        peazip
        wiremix # TUI pipewire mixer, replaces pavucontrol on waybar left-click
        nerd-fonts.jetbrains-mono
        bibata-cursors # Complete XCursor + Hyprcursor theme with all cursor poses
        adwaita-icon-theme # Standard GTK icon/cursor fallback
    ];
}
