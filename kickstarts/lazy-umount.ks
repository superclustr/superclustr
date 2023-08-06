%post --nochroot

echo "Probing if all processes have stopped using $INSTALL_ROOT and its submounts"

# Check for submounts and unmount them
mount | grep "$INSTALL_ROOT" | awk '{ print $3 }' | sort -r | while read mnt; do
    echo "Attempting to unmount: $mnt"
    umount $mnt
done

MAX_RETRIES=5
RETRY_COUNT=0

while lsof | grep "$INSTALL_ROOT" && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    echo "Processes still using $INSTALL_ROOT:"
    lsof | grep "$INSTALL_ROOT"

    # Kill processes using fuser
    echo "Attempting to kill processes using fuser..."
    fuser -k -M -m $INSTALL_ROOT

    echo "Sleeping for a short period to allow processes to terminate..."
    sleep 10s

    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Retry count: $RETRY_COUNT"
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "Max retries reached. Unable to clear all processes using $INSTALL_ROOT."
else
    echo "All processes stopped using $INSTALL_ROOT and its submounts successfully"
    # Fake mount
    mount --bind $INSTALL_ROOT $INSTALL_ROOT
fi

%end