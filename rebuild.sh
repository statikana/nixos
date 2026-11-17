EXEC_DIR=`pwd`
CFG_DIR="/home/ryan/nixos"
NOW=`date +'%Y-%m-%d %T'`

cd ${CFG_DIR}
echo "(moved into ${CFG_DIR})"
echo "dont forget you can use reb-offline or \"rebuild.sh offline\" if you dont have internet to skip git push"
git add .
git commit -m "nixos-rebuild [$NOW]"
if [[ $1 != "offline" ]]; then git push
fi
sudo nixos-rebuild switch --flake ~/nixos#ryan-nixos
cd $EXEC_DIR # return to original directory
echo "(moved back to ${EXEC_DIR})"
