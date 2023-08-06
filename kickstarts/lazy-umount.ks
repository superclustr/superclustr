%post --nochroot
# Hotfix to try to stop umount probs
# Bug https://bugzilla.redhat.com/show_bug.cgi?id=509427
echo "Unable to unmount $INSTALL_ROOT normally, using lazy unmount"
while (/usr/bin/lsof /dev/loop* | grep -v "$0" | grep "$INSTALL_ROOT")
do
	echo "Sleeping 15 seconds, waiting for successful $INSTALL_ROOT umount..."
	sleep 15s
done
echo "Lazy umount succeeded on $INSTALL_ROOT"
%end