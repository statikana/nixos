{ ... }: {

    virtualisation.docker = {
        enable = true;
        listenOptions = [ "/run/docker.sock" "0.0.0.0:2375" ];
    };
}