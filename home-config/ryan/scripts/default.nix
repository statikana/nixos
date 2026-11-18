{ lib, ... }: {
    home.activation.makeWaybarScriptsExecutable = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        find /home/ryan/nixos/home-config/ryan/scripts -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} +
    '';
}
