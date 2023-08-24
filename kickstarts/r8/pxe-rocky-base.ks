# Maintained by RelEng

%include pxe-rocky-base-spin.ks
%include pxe-rocky-common.ks

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

# Define Nameservers explicitly
cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

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
cp ../../assets/wallpaper.png $INSTALL_ROOT/usr/share/backgrounds/f36/default/f36-01-day.png
cp ../../assets/wallpaper.png $INSTALL_ROOT/usr/share/backgrounds/f36/default/f36-02-night.png
cp ../../assets/wallpaper.png $INSTALL_ROOT/usr/share/backgrounds/f36/default/f36.png
%end

%post
# Setup cobbler

mkdir -p /var/lib/cobbler/loaders/

# Legacy BIOS PXELINUX
cp /usr/share/syslinux/* /var/lib/cobbler/loaders/

# UEFI PXELINUX
(
    cd /tmp
    curl -O https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/Testing/6.04/syslinux-6.04-pre1.tar.gz
    tar -xzf syslinux-6.04-pre1.tar.gz
    cp syslinux-6.04-pre1/efi64/efi/syslinux.efi /var/lib/tftpboot/
    cp syslinux-6.04-pre1/efi64/com32/elflink/ldlinux/ldlinux.e64 /var/lib/tftpboot/
)

# Enable Cobblers Services
systemctl enable --force cobblerd.service
systemctl enable --force xinetd
systemctl enable --force tftp
%end

%post --nochroot
# Install PXE Syc Daemon
git clone --branch main --depth 1 https://GITLAB_PXE_SYNC_DAEMON_DEPLOY_USERNAME_PLACEHOLDER:GITLAB_PXE_SYNC_DAEMON_DEPLOY_TOKEN_PLACEHOLDER@gitlab.com/superclustr/pxe-sync-daemon.git $INSTALL_ROOT/home/liveuser/pxe-sync-daemon
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
Exec=sudo /home/liveuser/pxe-sync-daemon/venv/bin/python3.11 /home/liveuser/pxe-sync-daemon/main.py
Hidden=false
X-GNOME-Autostart-enabled=true
Name[en_US]=PXE Sync Daemon
Name=PXE Sync Daemon
Comment[en_US]=Starts PXE Sync Daemon on login
Comment=Starts PXE Sync Daemon on login
EOF

%end

%post
# Setup NFS Server
mkdir -p /mnt/nfsroot
cat > /etc/exports << 'EOF'
/mnt/nfsroot *(ro,sync,nohide,no_root_squash,no_subtree_check)
EOF

systemctl enable --force nfs-server
%end

%post
# Setup Firewall
firewall-cmd --add-service=nfs --permanent
firewall-cmd --add-service=dhcp --permanent
firewall-cmd --add-service=tftp --permanent
firewall-cmd --add-service=http --permanent
firewall-cmd --add-service=https --permanent
firewall-cmd --add-port=19999/tcp --permanent
firewall-cmd --add-port=67/udp --permanent
firewall-cmd --add-port=69/udp --permanent
%end

%post --erroronfail
# Install Netdata but don't start it immediately
curl https://my-netdata.io/kickstart.sh > /tmp/netdata-kickstart.sh && sh /tmp/netdata-kickstart.sh --prepare-offline-install-source /root/netdata-offline
/root/netdata-offline/install.sh --nightly-channel --dont-start-it --non-interactive
systemctl disable --force netdata
%end

%include lazy-umount.ks