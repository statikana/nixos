{ pkgs, lib, ... }:
let
    geminiDesktop = pkgs.symlinkJoin {
        name = "gemini-desktop";
        paths = [
            (pkgs.writeShellApplication {
                name = "gemini-desktop";
                text = ''
                    exec ${lib.getExe pkgs.google-chrome} --app=https://gemini.google.com "$@"
                '';
            })
            (pkgs.makeDesktopItem {
                name = "gemini-desktop";
                desktopName = "Gemini";
                genericName = "AI Assistant";
                comment = "Google Gemini web app";
                exec = "gemini-desktop %U";
                icon = "gemini-desktop";
                categories = [
                    "Network"
                    "Utility"
                    "Chat"
                ];
                startupWMClass = "chrome-gemini.google.com__-Default";
                startupNotify = true;
            })
            (pkgs.writeTextDir "share/icons/hicolor/scalable/apps/gemini-desktop.svg" ''
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
                  <defs>
                    <linearGradient id="gemini-grad" x1="0%" y1="100%" x2="100%" y2="0%">
                      <stop offset="0%" stop-color="#1BA1E3"/>
                      <stop offset="50%" stop-color="#4796E3"/>
                      <stop offset="100%" stop-color="#9B72CB"/>
                    </linearGradient>
                  </defs>
                  <path fill="url(#gemini-grad)" d="M12 1C12 7.075 7.075 12 1 12C7.075 12 12 16.925 12 23C12 16.925 16.925 12 23 12C16.925 12 12 7.075 12 1Z"/>
                </svg>
            '')
        ];
    };
in
{
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
        hyprpicker # colors
        cliphist
        pulseaudio
        peazip
        impala
        bluetuith # TUI bluetooth manager, replaces blueman-manager on waybar left-click
        wiremix # TUI pipewire mixer, replaces pavucontrol on waybar left-click
        nerd-fonts.jetbrains-mono
        bibata-cursors # Complete XCursor + Hyprcursor theme with all cursor poses
        adwaita-icon-theme # Standard GTK icon/cursor fallback
        
    ];
}
