{ ... }: {
    networking.hostName = "ryan-nixos";

    networking.wireless.enable = true; # Enables wireless support via wpa_supplicant.

    # networking.proxy.default = "http://user:password@proxy:port/";
    # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    networking.networkmanager.enable = true;
    # networking.nameservers = ["127.0.0.1"];

    # networking.firewall.allowedUDPPorts = [ ... ];
    # networking.firewall.enable = false;

    # NetworkManager-wait-online blocks boot for ~4-5s waiting for network-online.target;
    # nothing on this machine actually needs that guarantee at boot.
    systemd.services.NetworkManager-wait-online.enable = false;
}
