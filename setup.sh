#!/home/ryan/.nix-profile/bin/sh

# random setup things to do when first intializing
# this isn't exhaustive but i'll update it when I need to
# obviously I try to avoid these things when necessary
# since nixos is supposed to be delarative



# Make scripts executable (e.g. the ones used in waybar)
CONFIG_BASE="/home/ryan/nixos"
SCRIPT_BASE="${CONFIG_BASE}/home-config/ryan/scripts"
chmod +x --recursive ${SCRIPT_BASE}
