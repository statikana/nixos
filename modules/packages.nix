{
    config,
    pkgs,
    pkgs-unstable,
    lib,
    inputs,
    ...
}:

let
    # nixpkgs revision that ships opencode 1.18.x
    opencodePkgs =
        import
            (builtins.fetchTarball {
                url = "https://github.com/NixOS/nixpkgs/archive/c27cdad491a991b11ed731760aa2ef8db0cb0410.tar.gz";
                sha256 = "1r58xn9xdka8bw710i431srl3dmy7dyrhd32rjv709f2mkb6m1ix";
            })
            {
                inherit (pkgs.stdenv.hostPlatform) system;
            };
    commonsPkgs = with pkgs; [
        nss # libnss3, libnssutil3, libsmime3
        nspr # libnspr4
        alsa-lib # libasound
        at-spi2-core # libatk, libatk-bridge, libatspi
        cups # libcups
        libdrm
        libgbm
        libx11
        libxcb
        libxcomposite
        libxdamage
        libxext
        libxfixes
        libxrandr
        libxkbcommon
        expat
    ];
in

{
    nixpkgs.overlays = [
        (final: prev: {
            qgroundcontrol = prev.qgroundcontrol.overrideAttrs (old: {
                NIX_CFLAGS_COMPILE = "-Wno-error";
            });
            obsidian = prev.obsidian.overrideAttrs (old: rec {
                version = "1.15.0";
                src = prev.fetchurl {
                    url = "https://github.com/obsidianmd/obsidian-releases/releases/download/v${version}/obsidian-${version}.tar.gz";
                    hash = "sha256-dVlK4JkUygGR3eE8Bpfe5lMyIoejqAbBVRkzLZraFNM=";
                };
            });
            pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
                (python-final: python-prev: {
                    manim = python-prev.manim.overridePythonAttrs (old: {
                        # Click/Cloup help formatting differs ([COMMAND] vs COMMAND),
                        # matching the existing upstream-nixpkgs exclusion of test_manim_cfg_subcommand.
                        disabledTests = (old.disabledTests or [ ]) ++ [
                            "test_manim_init_subcommand"
                        ];
                    });
                })
            ];
        })
    ];

    environment.systemPackages =
        with pkgs;
        [
            # System
            hyprland

            # Editors
            kdePackages.kate
            vscode
            neovim

            # Version control
            git
            gh

            # Formatting
            nixfmt
            nixd

            # Languages
            rustup

            gnumake
            libgcc
            gcc

            (python3.withPackages (
                ps: with ps; [
                    # pip
                    requests
                    numpy
                    pandas
                    stable-baselines3
                    openmpi
                    pygame-ce
                    kconfiglib
                    sympy
                    manim
                ]
            ))

            rust-analyzer
            gdb
            lua51Packages.luarocks-nix

            # Development
            docker
            nodejs
            openmpi
            opencodePkgs.opencode
            claude-code
            cmake

            # CLI Utils
            ffmpeg
            dig                 # dns / http querying
            cloudflared         # CF outward tunnel daemon
            dnscrypt-proxy      # proxy utils
            wgcf                # idr
            wireguard-tools
            qbittorrent
            tree
            gparted
            cheese
            nmap
            hwinfo
            fastfetch
            btop
            nvtopPackages.full
            tmux
            unzip
            uv
            harbor-cli
            lldb
            nvitop
            wezterm
            php
            php84Packages.composer

            zoxide
            fzf # file find
            tldr # man summary
            atuin # commands
            lazygit
            jq # json

            ripgrep
            socat # workspace-listener.sh reads Hyprland's event socket
            tor
            p7zip
            parted
            uefitool
            ifrextractor-rs
            file
            pciutils
            usbutils
            psmisc
            libva-utils
            intel-gpu-tools
            nvme-cli
            acpi
            config.boot.kernelPackages.cpupower
            config.boot.kernelPackages.turbostat

            antigravity-cli
            google-chrome
            pandoc
            nautilus
            slack

            powertop
            dmidecode

            # Desktop apps
            qgroundcontrol
            discord
            bitwarden-desktop
            vinegar
            steam
            obsidian
            wine
            lyx
            texliveFull
            ghostscript
            poppler-utils
            librsvg
            manim           # math animation library
            chromium        
            glib            # gnome lib tools
            lufus           # rufus for linux
            ventoy          # flash iso
        ]
        ++ commonsPkgs;

    # Libraries Playwright's downloaded Chrome needs (headless browser testing).
    # Merged with the nix-ld libraries in programs.nix; exposed via /run/current-system/sw/share/nix-ld/lib.
    programs.nix-ld = {
        enable = true;
        libraries = commonsPkgs;
    };

    # link shared libs to the usual /usr/lib
    systemd.tmpfiles.rules = [
        "L+ /usr/lib - - - - /run/current-system/sw/share/nix-ld/lib"
    ];
}
