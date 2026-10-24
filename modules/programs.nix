{ pkgs, ... }: {
    programs = {
        # https://search.nixos.org/options?channel=26.05&query=programs.uwsm&type=options#show=option%253Aprograms.uwsm.waylandCompositors
        # uwsm = {
        #     enable = true;
        #     waylandCompositors.hyprland = {
        #         prettyName = "Hyprland w/ UWSM";
        #         comment = "Hyprland compositor managed by global UWSM program";
        #         binPath = "/run/current-system/bw/bin/Hyprland";
        #     };
        # }; # dont do this! handled already

        nix-ld = {
            enable = true;
            libraries = with pkgs; [
                gtk3
                glib
                pango
                harfbuzz
                at-spi2-atk
                cairo
                gdk-pixbuf
                libepoxy
                fontconfig
                freetype
                dbus
                systemd
                libusb1
                udev
                zlib
                openssl
                curl
                stdenv.cc.cc
            ];
        };

        firefox = {
            enable = true;
            preferences = {
                "media.ffmpeg.vaapi.enabled" = true;
                "media.hardware-video-decoding.force-enabled" = true;
                "media.rdd-ffmpeg.enabled" = true;
                "gfx.webrender.all" = true;
            };
        };

        steam.enable = true;

        mtr.enable = true;

        gnupg.agent = {
            enable = true;
            enableSSHSupport = true;
        };

        hyprland = {
            enable = true;
            withUWSM = true;
            xwayland.enable = true;
        };

    };
}
