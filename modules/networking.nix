{ ... }: {
    networking.hostName = "ryan-nixos";

    # NetworkManager manages Wi-Fi via wpa_supplicant; enabling networking.wireless
    # alongside it starts a duplicate standalone wpa_supplicant.service
    # networking.wireless.enable = true;

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
