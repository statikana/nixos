{ ... }: {
    networking.hostName = "ryan-nixos";
    
    networking.wireless.enable = true;    # Enables wireless support via wpa_supplicant.

    # networking.proxy.default = "http://user:password@proxy:port/";
    # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    networking.networkmanager.enable = true;
    
    # for dockerd I think
    networking.firewall.allowedTCPPorts = [ 2375 ];
    # networking.firewall.allowedUDPPorts = [ ... ];
    # networking.firewall.enable = false;
}