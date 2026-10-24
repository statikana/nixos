{ ... }: {
    hardware.bluetooth = {
        enable = true;
        powerOnBoot = false;
        settings = {
            General = {
                Experimental = true;
                # FastConnectable = true uses a 22.5ms page scan interval (56 wakeups/sec)
                FastConnectable = false;
            };
            Policy = {
                AutoEnable = false;
            };
        };
    };
}
