%post --nochroot
# Hotfix to try to hold umount until all processes stopped on the mouted filesystem
# Bug https://bugzilla.redhat.com/show_bug.cgi?id=509427
MAX_RETRIES=5
RETRY_COUNT=0

echo "Probing if all processes have stopped using $INSTALL_ROOT and its submounts"

while lsof | grep "$INSTALL_ROOT" && [ $RETRY_COUNT -lt $MAX_RETRIES ]
do
    echo "Processes still using $INSTALL_ROOT:"
    lsof | grep "$INSTALL_ROOT"

	# Fake mount
	mount --bind $INSTALL_ROOT $INSTALL_ROOT
    
    # Kill processes
    lsof | grep "$INSTALL_ROOT" | awk '{print $2}' | uniq | xargs kill -9
    
    echo "Sleeping for a short period to allow processes to terminate..."
    sleep 5s

    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Retry count: $RETRY_COUNT"
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "Max retries reached. Unable to clear all processes using $INSTALL_ROOT."
else
    echo "All processes stopped using $INSTALL_ROOT and its submounts successfully"
fi
%end