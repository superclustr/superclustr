%post --nochroot
# Hotfix to try to hold umount until all processes stopped on the mouted filesystem
# Bug https://bugzilla.redhat.com/show_bug.cgi?id=509427
echo "Probing if all processes have stopped using $INSTALL_ROOT and its submounts"
while lsof | grep "$INSTALL_ROOT"
do
    echo "Sleeping 15 seconds, waiting for processes to stop using the filesystems under $INSTALL_ROOT...."
    sleep 15s
done
mount --bind $INSTALL_ROOT $INSTALL_ROOT
%end