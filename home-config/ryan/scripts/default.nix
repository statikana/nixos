{ lib, ... }: {
    home.activation.makeWaybarScriptsExecutable = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        chmod -R +x /home/ryan/nixos/home-config/ryan/scripts
    '';
}
