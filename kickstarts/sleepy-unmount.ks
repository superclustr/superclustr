%post --nochroot
# Hotfix to try to stop umount probs
# Bug https://bugzilla.redhat.com/show_bug.cgi?id=509427
while (/usr/sbin/lsof /dev/loop* | grep -v "$0" | grep "$INSTALL_ROOT")
do
	echo "Sleeping 5 seconds, waiting for successful $INSTALL_ROOT umount..."
	sleep 5s
done
%end