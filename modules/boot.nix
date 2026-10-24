{ pkgs, ... }: {
    boot = {
        loader = {
            systemd-boot.enable = true;
            efi.canTouchEfiVariables = true;
        };

        kernelPackages = pkgs.linuxPackages_6_12;

        kernelParams = [
            "nowatchdog"
            "i915.enable_fbc=1"
            "i915.enable_guc=3"
        ];

        # iTCO_wdt: disable Intel hardware watchdog timer
        # xe: avoid loading duplicate Intel Xe driver alongside i915
        blacklistedKernelModules = [
            "iTCO_wdt"
            "xe"
        ];

        # damn you, lenovo
        extraModprobeConfig = ''
            options thinkpad_acpi fan_control=1
            options iwlwifi power_save=1
            options iwlmvm power_scheme=3
            options battery cache_time=5000
            options snd_hda_intel power_save=1 power_save_controller=Y
        '';
    };
}
