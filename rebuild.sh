NOW=`date +'%Y-%m-%d %T'`
git add .
git commit -m "nixos-rebuild [$NOW]"
if [[ $1 != "offline" ]]; then git push
fi
sudo nixos-rebuild switch --flake ~/nixos#ryan-nixos