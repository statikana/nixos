#!/home/ryan/.nix-profile/bin/sh

mode=$(cat $XDG_RUNTIME_DIR/fan-mode 2>/dev/null || echo auto)

case "$mode" in
    quiet) next=max ;;
    auto) next=quiet ;;
    max) next=auto ;;
    *) next=auto ;;
esac

/home/ryan/nixos/home-config/ryan/scripts/fan/fan-"$next".sh