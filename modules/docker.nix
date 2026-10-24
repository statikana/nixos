{ ... }: {

    virtualisation.docker = {
        enable = true;
        # Socket-activated via docker.socket on first `docker` command instead of
        # running dockerd + containerd continuously from boot
        enableOnBoot = false;
    };
}
