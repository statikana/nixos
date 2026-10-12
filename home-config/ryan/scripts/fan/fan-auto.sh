#!/home/ryan/.nix-profile/bin/sh

# permission in security.nix to start/stop thinkfan
sudo /run/current-system/sw/bin/systemctl start thinkfan.service # ensure on
echo "auto" | tee $XDG_RUNTIME_DIR/fan-mode >/dev/null
echo "level auto" | tee /proc/acpi/ibm/fan >/dev/null