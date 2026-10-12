#!/home/ryan/.nix-profile/bin/sh

if nmcli network connectivity | grep -q "full"; then
    nmcli network off
else
    nmcli network on
fi