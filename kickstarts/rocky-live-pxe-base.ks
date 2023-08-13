# Maintained by RelEng

%include rocky-live-pxe-base-spin.ks
%include rocky-live-pxe-common.ks

%post

# set default GTK+ theme for root (see #683855, #689070, #808062)
cat > /root/.gtkrc-2.0 << EOF
include "/usr/share/themes/Adwaita/gtk-2.0/gtkrc"
include "/etc/gtk-2.0/gtkrc"
gtk-theme-name="Adwaita"
EOF
mkdir -p /root/.config/gtk-3.0
cat > /root/.config/gtk-3.0/settings.ini << EOF
[Settings]
gtk-theme-name = Adwaita
EOF

# add initscript
cat >> /etc/rc.d/init.d/livesys << EOF

# are we *not* able to use wayland sessions?
if strstr "\`cat /proc/cmdline\`" nomodeset ; then
PLASMA_SESSION_FILE="plasmax11.desktop"
else
PLASMA_SESSION_FILE="plasma.desktop"
fi

# set up autologin for user liveuser
if [ -f /etc/sddm.conf ]; then
sed -i 's/^#User=.*/User=liveuser/' /etc/sddm.conf
sed -i "s/^#Session=.*/Session=\${PLASMA_SESSION_FILE}/" /etc/sddm.conf
else
cat > /etc/sddm.conf << SDDM_EOF
[Autologin]
User=liveuser
Session=\${PLASMA_SESSION_FILE}
SDDM_EOF
fi

# debrand
#sed -i "s/Red Hat Enterprise/Rocky/g" /usr/share/anaconda/gnome/rhel-welcome.desktop
#sed -i "s/RHEL/Rocky Linux/g" /usr/share/anaconda/gnome/rhel-welcome
#sed -i "s/Red Hat Enterprise/Rocky/g" /usr/share/anaconda/gnome/rhel-welcome
#sed -i "s/org.fedoraproject.AnacondaInstaller/fedora-logo-icon/g" /usr/share/anaconda/gnome/rhel-welcome
#sed -i "s/org.fedoraproject.AnacondaInstaller/fedora-logo-icon/g" /usr/share/applications/liveinst.desktop

# set executable bit disable KDE security warning
chmod +x /usr/share/applications/liveinst.desktop
mkdir /home/liveuser/Desktop
cp -a /usr/share/applications/liveinst.desktop /home/liveuser/Desktop/

if [ -f /usr/share/anaconda/gnome/rhel-welcome.desktop   ]; then
  mkdir -p ~liveuser/.config/autostart
  cp /usr/share/anaconda/gnome/rhel-welcome.desktop /usr/share/applications/
  cp /usr/share/anaconda/gnome/rhel-welcome.desktop ~liveuser/.config/autostart/
fi

# Set akonadi backend
mkdir -p /home/liveuser/.config/akonadi
cat > /home/liveuser/.config/akonadi/akonadiserverrc << AKONADI_EOF
[%General]
Driver=QSQLITE3
AKONADI_EOF

# Disable plasma-pk-updates if applicable
rpm -e plasma-pk-updates

# "Disable plasma-discover-notifier"
mkdir -p /home/liveuser/.config/autostart
cp -a /etc/xdg/autostart/org.kde.discover.notifier.desktop /home/liveuser/.config/autostart/
echo 'Hidden=true' >> /home/liveuser/.config/autostart/org.kde.discover.notifier.desktop

# Disable baloo
cat > /home/liveuser/.config/baloofilerc << BALOO_EOF
[Basic Settings]
Indexing-Enabled=false
BALOO_EOF

mkdir -p ~liveuser/.kde/share/config/

# Disable kres-migrator
cat > /home/liveuser/.kde/share/config/kres-migratorrc << KRES_EOF
[Migration]
Enabled=false
KRES_EOF

# Disable kwallet migrator
cat > /home/liveuser/.config/kwalletrc << KWALLET_EOL
[Migration]
alreadyMigrated=true
KWALLET_EOL

# make sure to set the right permissions and selinux contexts
chown -R liveuser:liveuser /home/liveuser/
restorecon -R /home/liveuser/
restorecon -R /

EOF

systemctl enable --force sddm.service
dnf config-manager --set-enabled powertools
%end

%post --erroronfail
# Attempt to ping google.com 10 times, and exit if it's unsuccessful
ATTEMPTS=10
for i in $(seq 1 $ATTEMPTS); do
    if ping -c1 google.com &>/dev/null; then
        # Success, break the loop and move on
        break
    elif [ $i -eq $ATTEMPTS ]; then
        # If this was the last attempt, exit with an error
        echo "Network is not up, exiting"
        exit 1
    else
        # Sleep for a second before the next attempt
        sleep 1
    fi
done
%end

%post --nochroot
# Copying desired wallpaper image to the target system (default, day, and night)
cp /mnt/assets/wallpaper.png $INSTALL_ROOT/usr/share/backgrounds/f36/default/f36-01-day.png
cp /mnt/assets/wallpaper.png $INSTALL_ROOT/usr/share/backgrounds/f36/default/f36-02-night.png
cp /mnt/assets/wallpaper.png $INSTALL_ROOT/usr/share/backgrounds/f36/default/f36.png
%end

%post
# Let cobbler handle the DHCP configuration
sudo -S sed -i 's/manage_dhcp: false/manage_dhcp: true/g' /etc/cobbler/settings.yaml

# Enable cobbler service
systemctl enable --force cobblerd.service
%end

%post --nochroot
# Install PXE Syc Daemon

# Ensure GitHub's authenticity
echo "github.com,140.82.121.4 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=" > /root/.ssh/known_hosts

git clone --branch v1.0.4 --depth 1 git@github.com:superclustr/pxe-sync-daemon.git $INSTALL_ROOT/home/liveuser/pxe-sync-daemon
%end

%post
# Set up virtual environment and install dependencies
(
cd /home/liveuser/pxe-sync-daemon
/usr/bin/python3.11 -m venv /home/liveuser/pxe-sync-daemon/venv
source /home/liveuser/pxe-sync-daemon/venv/bin/activate
/home/liveuser/pxe-sync-daemon/venv/bin/pip install --upgrade pip
/home/liveuser/pxe-sync-daemon/venv/bin/pip install -r requirements.txt
)

mkdir -p /home/liveuser/download_directory
mkdir -p /home/liveuser/.config/autostart/
cat > /home/liveuser/.config/autostart/pxe-sync-daemon.desktop << EOF
[Desktop Entry]
Type=Application
Exec=sudo /home/liveuser/pxe-sync-daemon/venv/bin/python3.11 /home/liveuser/pxe-sync-daemon/main.py -d /home/liveuser/download_directory
Hidden=false
X-GNOME-Autostart-enabled=true
Name[en_US]=PXE Sync Daemon
Name=PXE Sync Daemon
Comment[en_US]=Starts PXE Sync Daemon on login
Comment=Starts PXE Sync Daemon on login
EOF

%end

%post --erroronfail
# Connect Netdata Monitoring
curl https://my-netdata.io/kickstart.sh > /tmp/netdata-kickstart.sh && sh /tmp/netdata-kickstart.sh --stable-channel --claim-token rP5phC2xRoZkBNJkZsQSbmAJrG3qxI2ZOyL8sOHZKJ0x2Wr0BoZ-6FjFRCIucPyYCbzYlxmXNrfcIkaC5hDANUHHnUn2TvpwnJyEkq6AwUd1QmBzEpIap2rR7Pak_fyugBO-lI8 --claim-rooms 8b3683fd-c4bf-4070-a4de-df6a58856de4 --claim-url https://app.netdata.cloud --dont-start-it

# Overwrite Netdata configuration
cat > /etc/netdata/netdata.conf << EOF
[General]
    run as user = netdata
    page cache size = 32
    dbengine multihost disk space = 256

[host labels]
    type = pxe
EOF

%end

%include lazy-umount.ks
