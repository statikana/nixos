{ ... }: {
    boot.loader.systemd-boot.enable = true;
    
    boot.loader.efi.canTouchEfiVariables = true;

    boot.kernelPackages = pkgs.linuxPackages_6_12;
}