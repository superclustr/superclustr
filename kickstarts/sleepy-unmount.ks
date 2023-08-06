%post --nochroot
# Hotfix to try to stop umount probs
# Bug https://bugzilla.redhat.com/show_bug.cgi?id=509427
while (/usr/sbin/lsof /dev/loop* | grep -v "$0" | grep "$INSTALL_ROOT")
do
	sleep 5s
done
%end