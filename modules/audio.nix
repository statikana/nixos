{ ... }: {
    # pipewire
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        wireplumber = {
            enable = true;
            extraConfig = {
                # Stop WirePlumber from holding /dev/video* (uvcvideo) open via libcamera
                "10-disable-camera" = {
                    "wireplumber.profiles" = {
                        main = {
                            "monitor.libcamera" = "disabled";
                        };
                    };
                };
                # Disable the NVIDIA dGPU's HDMI/DP audio controller (01:00.1) so
                # audio device probing never wakes the RTX A2000 out of D3cold
                "51-disable-nvidia-audio" = {
                    "monitor.alsa.rules" = [
                        {
                            matches = [
                                {
                                    "device.name" = "alsa_card.pci-0000_01_00.1";
                                }
                            ];
                            actions = {
                                update-props = {
                                    "device.disabled" = true;
                                };
                            };
                        }
                    ];
                };
            };
        };

        #jack.enable = true;
    };
}
