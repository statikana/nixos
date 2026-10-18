{ pkgs, ... }: {
    boot = {
        loader = {
            systemd-boot.enable = true;
            efi.canTouchEfiVariables = true;
        };

        kernelPackages = pkgs.linuxPackages_6_12;

        # damn you, lenovo
        extraModprobeConfig = ''options thinkpad_acpi fan_control=1'';
    };
}
