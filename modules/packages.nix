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
  opencodePkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/c27cdad491a991b11ed731760aa2ef8db0cb0410.tar.gz";
    sha256 = "1r58xn9xdka8bw710i431srl3dmy7dyrhd32rjv709f2mkb6m1ix";
  }) {
    inherit (pkgs.stdenv.hostPlatform) system;
  };
in

{
  environment.systemPackages = with pkgs; [
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
    clang-tools

    # Languages
    rustup

    gnumake
    libgcc
    gcc

    (python3.withPackages (ps: with ps; [
        requests
        numpy
        pandas
        stable-baselines3
        openmpi
        pygame-ce
    ]))

    rust-analyzer
    gdb
    lua51Packages.luarocks-nix

    # Development
    docker
    nodejs
    openmpi
    opencodePkgs.opencode

    # CLI Utils
    ffmpeg
    cloudflared
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
    wezterm
    nvitop

    zoxide
    fzf # file find
    tldr # man summary
    atuin # commands
    lazygit
    jq # json

    ripgrep
    cryptsetup

    # Desktop apps
    qgroundcontrol
    discord
    bitwarden-desktop
    vinegar
    steam
  ];
}
