# Generated by pykickstart v3.32
#version=DEVEL
# X Window System configuration information
xconfig  --startxonboot
# Keyboard layouts
keyboard 'us'
# Root password
rootpw --iscrypted --lock locked
# System language
lang en_US.UTF-8
# Shutdown after installation
shutdown
# Network information
network --bootproto=dhcp --device=link --nameserver=8.8.8.8,8.8.4.4 --activate
# Firewall configuration
firewall --enabled --service=mdns
# Use network installation
url --url https://download.rockylinux.org/stg/rocky/8/BaseOS/$basearch/os/
repo --name="BaseOS" --baseurl=http://dl.rockylinux.org/pub/rocky/8/BaseOS/$basearch/os/ --cost=200
repo --name="AppStream" --baseurl=http://dl.rockylinux.org/pub/rocky/8/AppStream/$basearch/os/ --cost=200
repo --name="PowerTools" --baseurl=http://dl.rockylinux.org/pub/rocky/8/PowerTools/$basearch/os/ --cost=200
repo --name="extras" --baseurl=http://dl.rockylinux.org/pub/rocky/8/extras/$basearch/os --cost=200
repo --name="epel" --baseurl=https://dl.fedoraproject.org/pub/epel/8/Everything/$basearch/ --cost=200
repo --name="epel-modular" --baseurl=https://dl.fedoraproject.org/pub/epel/8/Modular/$basearch/ --cost=200
# System timezone
timezone US/Eastern
# SELinux configuration
selinux --permissive
# System services
services --disabled="sshd" --enabled="NetworkManager,ModemManager"
# System bootloader configuration
bootloader --location=none
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all
# Disk partitioning information
part / --fstype="ext4" --size=5120
part / --size=7300

%post
# FIXME: it'd be better to get this installed from a package
cat > /etc/rc.d/init.d/livesys << EOF
#!/bin/bash
#
# live: Init script for live image
#
# chkconfig: 345 00 99
# description: Init script for live image.
### BEGIN INIT INFO
# X-Start-Before: display-manager chronyd
### END INIT INFO

. /etc/init.d/functions

if ! strstr "\`cat /proc/cmdline\`" rd.live.image || [ "\$1" != "start" ]; then
    exit 0
fi

if [ -e /.liveimg-configured ] ; then
    configdone=1
fi

exists() {
    which \$1 >/dev/null 2>&1 || return
    \$*
}

livedir="LiveOS"
for arg in \`cat /proc/cmdline\` ; do
  if [ "\${arg##rd.live.dir=}" != "\${arg}" ]; then
    livedir=\${arg##rd.live.dir=}
    continue
  fi
  if [ "\${arg##live_dir=}" != "\${arg}" ]; then
    livedir=\${arg##live_dir=}
  fi
done

# Enable swap unless requested otherwise
swaps=\`blkid -t TYPE=swap -o device\`
if ! strstr "\`cat /proc/cmdline\`" noswap && [ -n "\$swaps" ] ; then
  for s in \$swaps ; do
    action "Enabling swap partition \$s" swapon \$s
  done
fi
if ! strstr "\`cat /proc/cmdline\`" noswap && [ -f /run/initramfs/live/\${livedir}/swap.img ] ; then
  action "Enabling swap file" swapon /run/initramfs/live/\${livedir}/swap.img
fi

# Support for persistent homes
mountPersistentHome() {
  # support label/uuid
  if [ "\${homedev##LABEL=}" != "\${homedev}" -o "\${homedev##UUID=}" != "\${homedev}" ]; then
    homedev=\`/sbin/blkid -o device -t "\$homedev"\`
  fi

  # if we're given a file rather than a blockdev, loopback it
  if [ "\${homedev##mtd}" != "\${homedev}" ]; then
    # mtd devs don't have a block device but get magic-mounted with -t jffs2
    mountopts="-t jffs2"
  elif [ ! -b "\$homedev" ]; then
    loopdev=\`losetup -f\`
    if [ "\${homedev##/run/initramfs/live}" != "\${homedev}" ]; then
      action "Remounting live store r/w" mount -o remount,rw /run/initramfs/live
    fi
    losetup \$loopdev \$homedev
    homedev=\$loopdev
  fi

  # if it's encrypted, we need to unlock it
  if [ "\$(/sbin/blkid -s TYPE -o value \$homedev 2>/dev/null)" = "crypto_LUKS" ]; then
    echo
    echo "Setting up encrypted /home device"
    plymouth ask-for-password --command="cryptsetup luksOpen \$homedev EncHome"
    homedev=/dev/mapper/EncHome
  fi

  # and finally do the mount
  mount \$mountopts \$homedev /home
  # if we have /home under what's passed for persistent home, then
  # we should make that the real /home.  useful for mtd device on olpc
  if [ -d /home/home ]; then mount --bind /home/home /home ; fi
  [ -x /sbin/restorecon ] && /sbin/restorecon /home
  if [ -d /home/liveuser ]; then USERADDARGS="-M" ; fi
}

# Help locate persistent homes
findPersistentHome() {
  for arg in \`cat /proc/cmdline\` ; do
    if [ "\${arg##persistenthome=}" != "\${arg}" ]; then
      homedev=\${arg##persistenthome=}
    fi
  done
}

if strstr "\`cat /proc/cmdline\`" persistenthome= ; then
  findPersistentHome
elif [ -e /run/initramfs/live/\${livedir}/home.img ]; then
  homedev=/run/initramfs/live/\${livedir}/home.img
fi

# Mount the persistent home if it's available
if ! strstr "\`cat /proc/cmdline\`" nopersistenthome && [ -n "\$homedev" ] ; then
  action "Mounting persistent /home" mountPersistentHome
fi

if [ -n "\$configdone" ]; then
  exit 0
fi

# Create the liveuser (no password) so automatic logins and sudo works
action "Adding live user" useradd \$USERADDARGS -c "Live System User" liveuser
passwd -d liveuser > /dev/null
usermod -aG wheel liveuser > /dev/null

# Same for root
passwd -d root > /dev/null

# Turn off firstboot (similar to a DVD/minimal install, where it asks
# for the user to accept the EULA before bringing up a TTY)
systemctl --no-reload disable firstboot-text.service 2> /dev/null || :
systemctl --no-reload disable firstboot-graphical.service 2> /dev/null || :
systemctl stop firstboot-text.service 2> /dev/null || :
systemctl stop firstboot-graphical.service 2> /dev/null || :

# Prelinking damages the images
sed -i 's/PRELINKING=yes/PRELINKING=no/' /etc/sysconfig/prelink &>/dev/null || :

# Turn off mdmonitor by default
systemctl --no-reload disable mdmonitor.service 2> /dev/null || :
systemctl --no-reload disable mdmonitor-takeover.service 2> /dev/null || :
systemctl stop mdmonitor.service 2> /dev/null || :
systemctl stop mdmonitor-takeover.service 2> /dev/null || :

# Disable cron
systemctl --no-reload disable crond.service 2> /dev/null || :
systemctl --no-reload disable atd.service 2> /dev/null || :
systemctl stop crond.service 2> /dev/null || :
systemctl stop atd.service 2> /dev/null || :

# Disable abrt
systemctl --no-reload disable abrtd.service 2> /dev/null || :
systemctl stop abrtd.service 2> /dev/null || :

# Don't sync the system clock when running live (RHBZ #1018162)
sed -i 's/rtcsync//' /etc/chrony.conf

# Mark things as configured
touch /.liveimg-configured

# add static hostname to work around xauth bug
# https://bugzilla.redhat.com/show_bug.cgi?id=679486
# the hostname must be something else than 'localhost'
# https://bugzilla.redhat.com/show_bug.cgi?id=1370222
echo "localhost-live" > /etc/hostname

EOF

# HAL likes to start late.
cat > /etc/rc.d/init.d/livesys-late << EOF
#!/bin/bash
#
# live: Late init script for live image
#
# chkconfig: 345 99 01
# description: Late init script for live image.

. /etc/init.d/functions

if ! strstr "\`cat /proc/cmdline\`" rd.live.image || [ "\$1" != "start" ] || [ -e /.liveimg-late-configured ] ; then
    exit 0
fi

exists() {
    which \$1 >/dev/null 2>&1 || return
    \$*
}

touch /.liveimg-late-configured

# Read some stuff out of the kernel cmdline
for o in \`cat /proc/cmdline\` ; do
    case \$o in
    ks=*)
        ks="--kickstart=\${o#ks=}"
        ;;
    xdriver=*)
        xdriver="\${o#xdriver=}"
        ;;
    esac
done

# If liveinst or textinst is given, start installer
if strstr "\`cat /proc/cmdline\`" liveinst ; then
   plymouth --quit
   /usr/sbin/liveinst \$ks
fi
if strstr "\`cat /proc/cmdline\`" textinst ; then
   plymouth --quit
   /usr/sbin/liveinst --text \$ks
fi

EOF

chmod 755 /etc/rc.d/init.d/livesys
/sbin/restorecon /etc/rc.d/init.d/livesys
/sbin/chkconfig --add livesys

chmod 755 /etc/rc.d/init.d/livesys-late
/sbin/restorecon /etc/rc.d/init.d/livesys-late
/sbin/chkconfig --add livesys-late

# Enable tmpfs for /tmp - this is a good idea
systemctl enable tmp.mount

# make it so that we don't do writing to the overlay for things which
# are just tmpdirs/caches
# note https://bugzilla.redhat.com/show_bug.cgi?id=1135475
cat >> /etc/fstab << EOF
vartmp   /var/tmp    tmpfs   defaults   0  0
EOF

# PackageKit likes to play games. Let's fix that.
rm -f /var/lib/rpm/__db*
releasever=$(rpm -q --qf '%{version}\n' --whatprovides system-release)
basearch=$(uname -i)
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-rockyofficial
echo "Packages within this LiveCD"
rpm -qa
# Note that running rpm recreates the rpm db files which aren't needed or wanted
rm -f /var/lib/rpm/__db*

# go ahead and pre-make the man -k cache (#455968)
/usr/bin/mandb

# make sure there aren't core files lying around
rm -f /core*

# remove random seed, the newly installed instance should make it's own
rm -f /var/lib/systemd/random-seed

# convince readahead not to collect
# FIXME: for systemd

echo 'File created by kickstart. See systemd-update-done.service(8).' \
    | tee /etc/.updated >/var/.updated

# Drop the rescue kernel and initramfs, we don't need them on the live media itself.
# See bug 1317709
rm -f /boot/*-rescue*

# Disable network service here, as doing it in the services line
# fails due to RHBZ #1369794 - the error is expected
/sbin/chkconfig network off

# Remove machine-id on generated images
rm -f /etc/machine-id
touch /etc/machine-id

# add initscript
cat >> /etc/rc.d/init.d/livesys << EOF

if [ -f /usr/share/anaconda/gnome/rhel-welcome.desktop  ]; then
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

# Disable baloo
cat > /home/liveuser/.config/baloofilerc << BALOO_EOF
[Basic Settings]
Indexing-Enabled=false
BALOO_EOF

# make sure to set the right permissions and selinux contexts
chown -R liveuser:liveuser /home/liveuser/
restorecon -R /home/liveuser/
restorecon -R /

EOF
dnf config-manager --set-enabled powertools
systemctl enable --force sddm.service
%end

%post
# Libvirtd does not like booting on its own
cat > /etc/systemd/system/libvirtd.timer << EOF
[Unit]
Description=Starting Virtualization daemon

[Timer]
# Time to wait after boot before activation
OnBootSec=5min
# The unit that this timer activates
Unit=libvirtd.service

[Install]
WantedBy=timers.target
EOF

systemctl enable --force libvirtd.timer
systemctl enable --force libvirtd
usermod -a -G libvirt liveuser
%end

%post --nochroot
cp $INSTALL_ROOT/usr/share/licenses/*-release/* $LIVE_ROOT/

# only works on x86_64
if [ "$(uname -i)" = "i386" -o "$(uname -i)" = "x86_64" ]; then
    # For livecd-creator builds
    if [ ! -d $LIVE_ROOT/LiveOS ]; then mkdir -p $LIVE_ROOT/LiveOS ; fi
    cp /usr/bin/livecd-iso-to-disk $LIVE_ROOT/LiveOS

    # For lorax/livemedia-creator builds
    sed -i '
    /## make boot.iso/ i\
    # Add livecd-iso-to-disk script to .iso filesystem at /LiveOS/\
    <% f = "usr/bin/livecd-iso-to-disk" %>\
    %if exists(f):\
        install ${f} ${LIVEDIR}/${f|basename}\
    %endif\
    ' /usr/share/lorax/templates.d/99-generic/live/x86.tmpl
fi

%end

%post
# Configure custom MOTD
cat > /etc/custom-motd.sh << 'EOF'
#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Display Legal Warning
echo -e "\nWARNING: Unauthorized access to this system is forbidden and will be prosecuted by law."
echo -e "By accessing this system, you agree that your actions may be monitored if unauthorized usage is suspected.\n"

# Display OS & Host details
echo -e "Hostname: $(hostname)"
echo -e "Operating System: $(cat /etc/redhat-release)"

# Display IP addresses
echo -e "\nIPv4 Addresses:"
ip -o -4 addr list | awk -F '[ /]+' '/global/ {print $4}' | while read -r line; do
    echo "- $line"
done

IPV6_ADDRS=$(ip -o -6 addr list | awk -F '[ /]+' '/global/ {print $4}')
if [[ ! -z $IPV6_ADDRS ]]; then
    echo -e "IPv6 Addresses:"
    echo "$IPV6_ADDRS" | while read -r line; do
        echo "- $line"
    done
fi

# Netdata Monitoring Notification
echo -e "\nThis system is attached to Netdata Cloud monitoring system.\nhttps://www.netdata.cloud/\n"

# Failed SSH Login Attempts
echo -e "=== Failed SSH Login Attempts ==="
FAILED_ATTEMPTS=$(journalctl _SYSTEMD_UNIT=sshd.service | grep 'Failed password' | tail -n 5)
if [[ ! -z $FAILED_ATTEMPTS ]]; then
    echo "$FAILED_ATTEMPTS"
    echo -e "${YELLOW}Please review any suspicious activity.${NC}"
else
    echo "No recent failed SSH attempts."
fi

# Recent sudo executions without permission
echo -e "\n=== Recent sudo executions without permission ==="
SUDO_DENIED=$(journalctl _SYSTEMD_UNIT=sudo.service | grep 'permission denied' | tail -n 5)
if [[ ! -z $SUDO_DENIED ]]; then
    echo "$SUDO_DENIED"
    echo -e "${YELLOW}Ensure user permissions are correctly configured.${NC}"
else
    echo "No recent sudo permission denials."
fi

# Active GitLab Runners
echo -e "\n=== Active GitLab Runners ==="
gitlab-runner list

# Currently running Virtual Machines
echo -e "\n=== Currently running Virtual Machines ==="
virsh list --all
echo "(Erase all Virtual Machines using 'systemctl start cleanup_vms.service')"


# Currently running Docker Containers
echo -e "\n=== Currently Running Docker Containers ==="
DOCKER_CONTAINERS=$(docker ps --format '{{.Names}} - {{.Image}}')
if [[ ! -z $DOCKER_CONTAINERS ]]; then
    echo "$DOCKER_CONTAINERS"
else
    echo "No Docker containers are currently running."
fi

# Other custom checks can be added below

echo
EOF
chmod +x /etc/custom-motd.sh

cat >> /etc/profile <<EOF

# Log motd
/etc/custom-motd.sh
EOF
%end

%post
# Setup automatic updates
cat > /etc/dnf/automatic.conf << 'EOF'
[commands]
#  What kind of upgrade to perform:
# default                            = all available upgrades
# security                           = only the security upgrades
upgrade_type = default
random_sleep = 0

# Maximum time in seconds to wait until the system is on-line and able to
# connect to remote repositories.
network_online_timeout = 60

# To just receive updates use dnf-automatic-notifyonly.timer

# Whether updates should be downloaded when they are available, by
# dnf-automatic.timer. notifyonly.timer, download.timer and
# install.timer override this setting.
download_updates = yes

# Whether updates should be applied when they are available, by
# dnf-automatic.timer. notifyonly.timer, download.timer and
# install.timer override this setting.
apply_updates = yes


[emitters]
# Name to use for this system in messages that are emitted.  Default is the
# hostname.
# system_name = my-host

# How to send messages.  Valid options are stdio, email and motd.  If
# emit_via includes stdio, messages will be sent to stdout; this is useful
# to have cron send the messages.  If emit_via includes email, this
# program will send email itself according to the configured options.
# If emit_via includes motd, /etc/motd file will have the messages. if
# emit_via includes command_email, then messages will be send via a shell
# command compatible with sendmail.
# Default is email,stdio.
# If emit_via is None or left blank, no messages will be sent.
emit_via = stdio


[email]
# The address to send email messages from.
email_from = root@example.com

# List of addresses to send messages to.
email_to = root

# Name of the host to connect to to send email messages.
email_host = localhost


[command]
# The shell command to execute. This is a Python format string, as used in
# str.format(). The format function will pass a shell-quoted argument called
# `body`.
# command_format = "cat"

# The contents of stdin to pass to the command. It is a format string with the
# same arguments as `command_format`.
# stdin_format = "{body}"


[command_email]
# The shell command to use to send email. This is a Python format string,
# as used in str.format(). The format function will pass shell-quoted arguments
# called body, subject, email_from, email_to.
# command_format = "mail -Ssendwait -s {subject} -r {email_from} {email_to}"

# The contents of stdin to pass to the command. It is a format string with the
# same arguments as `command_format`.
# stdin_format = "{body}"

# The address to send email messages from.
email_from = root@example.com

# List of addresses to send messages to.
email_to = root


[base]
# This section overrides dnf.conf

# Use this to filter DNF core messages
debuglevel = 1
EOF

sudo systemctl enable --now dnf-automatic.timer
%end

%post
echo "[hetzner]
type = webdav
url = NEXUS_HETZNER_STORAGE_BOX_URL_PLACEHOLDER
vendor = other
user = NEXUS_HETZNER_STORAGE_BOX_USERNAME_PLACEHOLDER
pass = $(rclone obscure NEXUS_HETZNER_STORAGE_BOX_PASSWORD_PLACEHOLDER)" > /root/.config/rclone/rclone.conf

mkdir /mnt/nexus-storage

adduser nexus
RANDOM_PASSWORD=$(openssl rand -base64 12)
echo "nexus:${RANDOM_PASSWORD}" | chpasswd
echo "Generated password for 'nexus' is: ${RANDOM_PASSWORD}"

# Change Shell to Prevent Direct Login
usermod -s /sbin/nologin nexus

# Grant Permissions to the Storage
chown nexus:nexus /mnt/nexus-storage
chmod 700 /mnt/nexus-storage

cat > /etc/systemd/system/nexus-storage.service << EOF
[Unit]
Description=Mount Hetzner Storage Box using rclone/WebDAV
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/rclone mount hetzner:/ /mnt/nexus-storage --daemon
ExecStop=/bin/fusermount -uz /mnt/nexus-storage
Restart=on-failure
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

# Set permissions for /mnt/nexus-storage to be only readable and writable by root
chmod 700 /mnt/nexus-storage

# Create Sonatype Nexus Docker Container
docker create --name nexus -p 8081:8081 sonatype/nexus:oss

cat > /etc/systemd/system/nexus-docker.service << EOF
[Unit]
Description=Nexus Server
After=network.target

[Service]
Type=forking
LimitNOFILE = 65536
ExecStart=/usr/bin/docker run -d -p 8081:8081 -v /mnt/nexus-storage:/nexus-storage -e INSTALL4J_ADD_VM_PARAMS="-Xms1200m -Xmx1200m -XX:MaxDirectMemorySize=2g -Djava.util.prefs.userRoot=/nexus-storage/javadir" --name nexus sonatype/nexus:oss
ExecStop=/usr/bin/docker stop -t 2 nexus
User=nexus
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF

# Enable Nexus Services
systemctl enable --force nexus-storage.service
systemctl enable --force nexus-docker.service

mkdir -p /etc/ssl/certs/NEXUS_DOMAIN_NAME_PLACEHOLDER
cat > /etc/ssl/certs/NEXUS_DOMAIN_NAME_PLACEHOLDER/fullchain.pem << EOF
NEXUS_DOMAIN_SSL_CERTIFICATE_PUBLIC_KEY_PLACEHOLDER
EOF

mkdir -p /etc/ssl/private/NEXUS_DOMAIN_NAME_PLACEHOLDER
cat > /etc/ssl/private/NEXUS_DOMAIN_NAME_PLACEHOLDER/privkey.pem << EOF
NEXUS_DOMAIN_SSL_CERTIFICATE_PRIVATE_KEY_PLACEHOLDER
EOF

cat > /etc/ssl/private/ssl-dhparams.pem << EOF
NEXUS_DOMAIN_SSL_DHPARAMS_PLACEHOLDER
EOF

chown root:root /etc/ssl/private
find /etc/ssl/private -type d -exec chmod 700 {} \;
find /etc/ssl/private -type f -exec chmod 600 {} \;

cat > /etc/nginx/conf.d/nexus.conf << EOF
server {
    listen 80;
    server_name NEXUS_DOMAIN_NAME_PLACEHOLDER;

    return 301 https://$server_name$request_uri;
}
server {
    listen 443 ssl;
    server_name NEXUS_DOMAIN_NAME_PLACEHOLDER;

    # allow large uploads of files - refer to nginx documentation
    client_max_body_size 10G;

    ssl_certificate /etc/ssl/certs/NEXUS_DOMAIN_NAME_PLACEHOLDER/fullchain.pem;
    ssl_certificate_key /etc/ssl/private/NEXUS_DOMAIN_NAME_PLACEHOLDER/privkey.pem;

    ssl_session_cache shared:le_nginx_SSL:10m;
    ssl_session_timeout 1440m;
    ssl_session_tickets off;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;

    ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";
    ssl_dhparam  /etc/ssl/private/ssl-dhparams.pem;

    location / {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

systemctl enable --force nginx
%end

%post
cat > /usr/local/bin/build_libvirt_images.sh << 'EOF'
#!/bin/bash -e

DISK_SPACE="50G"

download_and_setup_image() {
    IMAGE_PATH="/var/lib/libvirt/images/$(basename $2)"
    if [ ! -f "$IMAGE_PATH" ]; then
        cd /var/lib/libvirt/images/ && \
        curl -O $1 && \
        curl -O $2 && \
        sha256sum -c $(basename $1) && \
        rm -f $(basename $1)
    fi
}

#############################################
# Rocky Linux 8
#############################################
VERSION="8.8"
IMAGE_NAME="Rocky-8-GenericCloud-Base-8.8-20230518.0.x86_64.qcow2"
download_and_setup_image \
    "https://download.rockylinux.org/pub/rocky/${VERSION}/images/x86_64/${IMAGE_NAME}.CHECKSUM" \
    "https://download.rockylinux.org/pub/rocky/${VERSION}/images/x86_64/${IMAGE_NAME}"

if [ ! -f "/var/lib/libvirt/images/${IMAGE_NAME}.GITLAB" ]; then
  cp /var/lib/libvirt/images/${IMAGE_NAME} /var/lib/libvirt/images/${IMAGE_NAME}.GITLAB
  qemu-img resize /var/lib/libvirt/images/${IMAGE_NAME}.GITLAB ${DISK_SPACE}
  cp /var/lib/libvirt/images/${IMAGE_NAME}.GITLAB /var/lib/libvirt/images/${IMAGE_NAME}.GITLAB.EXPANDED
  virt-resize --expand /dev/vda5 /var/lib/libvirt/images/${IMAGE_NAME}.GITLAB /var/lib/libvirt/images/${IMAGE_NAME}.GITLAB.EXPANDED
  mv /var/lib/libvirt/images/${IMAGE_NAME}.GITLAB.EXPANDED /var/lib/libvirt/images/${IMAGE_NAME}.GITLAB
  virt-customize -a /var/lib/libvirt/images/${IMAGE_NAME}.GITLAB \
      --network \
      --hostname "$(hostname)-rocky-${VERSION}" \
      --run-command 'curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh" | bash' \
      --run-command 'curl -s "https://packagecloud.io/install/repositories/github/git-lfs/script.rpm.sh" | bash' \
      --run-command 'useradd -m -p "" gitlab-runner -s /bin/bash' \
      --install curl,gitlab-runner,git,git-lfs,openssh-server,lorax-lmc-novirt,vim-minimal,pykickstart,lsof,openssh-clients,anaconda \
      --run-command "git lfs install --skip-repo" \
      --ssh-inject gitlab-runner:file:/home/gitlab-runner/.ssh/id_rsa.pub \
      --run-command "echo 'gitlab-runner ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers" \
      --run-command "sed -E 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\"/' -i /etc/default/grub" \
      --run-command "grub2-mkconfig -o /boot/grub2/grub.cfg"
fi

#############################################
# Rocky Linux 9
#############################################
VERSION="9.2"
IMAGE_NAME="Rocky-9-GenericCloud-Base-9.2-20230513.0.x86_64.qcow2"
download_and_setup_image \
    "https://download.rockylinux.org/pub/rocky/${VERSION}/images/x86_64/${IMAGE_NAME}.CHECKSUM" \
    "https://download.rockylinux.org/pub/rocky/${VERSION}/images/x86_64/${IMAGE_NAME}"

if [ ! -f "/var/lib/libvirt/images/${IMAGE_NAME}.GITLAB" ]; then
  cp /var/lib/libvirt/images/${IMAGE_NAME} /var/lib/libvirt/images/${IMAGE_NAME}.GITLAB
  qemu-img resize /var/lib/libvirt/images/${IMAGE_NAME}.GITLAB ${DISK_SPACE}
  cp /var/lib/libvirt/images/${IMAGE_NAME}.GITLAB /var/lib/libvirt/images/${IMAGE_NAME}.GITLAB.EXPANDED
  virt-resize --expand /dev/vda5 /var/lib/libvirt/images/${IMAGE_NAME}.GITLAB /var/lib/libvirt/images/${IMAGE_NAME}.GITLAB.EXPANDED
  mv /var/lib/libvirt/images/${IMAGE_NAME}.GITLAB.EXPANDED /var/lib/libvirt/images/${IMAGE_NAME}.GITLAB
  virt-customize -a /var/lib/libvirt/images/${IMAGE_NAME}.GITLAB \
      --network \
      --hostname "$(hostname)-rocky-${VERSION}" \
      --run-command 'curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh" | bash' \
      --run-command 'curl -s "https://packagecloud.io/install/repositories/github/git-lfs/script.rpm.sh" | bash' \
      --run-command 'useradd -m -p "" gitlab-runner -s /bin/bash' \
      --install curl,gitlab-runner,git,git-lfs,openssh-server,lorax-lmc-novirt,vim-minimal,pykickstart,lsof,openssh-clients,anaconda \
      --run-command "git lfs install --skip-repo" \
      --ssh-inject gitlab-runner:file:/home/gitlab-runner/.ssh/id_rsa.pub \
      --run-command "echo 'gitlab-runner ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers" \
      --run-command "sed -E 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\"/' -i /etc/default/grub" \
      --run-command "grub2-mkconfig -o /boot/grub2/grub.cfg"
fi
EOF

chmod +x /usr/local/bin/build_libvirt_images.sh

cat > /etc/systemd/system/build_libvirt_images.service << 'EOF'
[Unit]
Description=Build libvirt images
After=network-online.target

[Service]
ExecStart=/usr/local/bin/build_libvirt_images.sh
Type=oneshot
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable --force build_libvirt_images.service
%end

%post
# Setup GitLab Runners

# Declare your Runners
declare -A RUNNERS=(
    ["rocky-8.token"]="GITLAB_RUNNER_ROCKY_8_TOKEN_PLACEHOLDER"
    ["rocky-8.qcow2"]="Rocky-8-GenericCloud-Base-8.8-20230518.0.x86_64.qcow2.GITLAB"
    ["rocky-9.token"]="GITLAB_RUNNER_ROCKY_9_TOKEN_PLACEHOLDER"
    ["rocky-9.qcow2"]="Rocky-9-GenericCloud-Base-9.2-20230513.0.x86_64.qcow2.GITLAB"
    # Add more runners like this:
    # ["another_name.token"]="ANOTHER_TOKEN_PLACEHOLDER"
    # ["another_name.qcow2"]="ANOTHER_QCOW2_FILENAME"
)

# Install GitLab Runner
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh" | bash
dnf install -y gitlab-runner

# Generate Key with empty passphrase
mkdir -p /home/gitlab-runner/.ssh
ssh-keygen -t rsa -b 4096 -f /home/gitlab-runner/.ssh/id_rsa -N ""

mkdir -p /opt/libvirt-driver/

for runner_key in "${!RUNNERS[@]}"; do
    if [[ $runner_key == *.token ]]; then
        runner_name="${runner_key%.token}"
        runner_token="${RUNNERS[$runner_name.token]}"
        runner_qcow2="${RUNNERS[$runner_name.qcow2]}"
        for i in $(seq 1 $CONCURRENT_INSTANCES); do
            cat > /opt/libvirt-driver/vars-${runner_name}.sh << EOF
#!/usr/bin/env bash

# Export Information
runner_qcow2=${runner_qcow2}
runner_name=${runner_name}
EOF
            cat > /opt/libvirt-driver/base-${runner_name}.sh << 'EOF'
#!/usr/bin/env bash

# Get the script name
script_name_base="${0##*/}"

# Strip prefix and ".sh" suffix
desired_value_base="${script_name_base#*-}"
desired_value_base="${desired_value_base%.sh}"

# Source variables
source /opt/libvirt-driver/vars-${desired_value_base}.sh

VM_IMAGES_PATH="/var/lib/libvirt/images"
BASE_VM_IMAGE="$VM_IMAGES_PATH/${runner_qcow2}"
VM_ID="runner-$CUSTOM_ENV_CI_RUNNER_ID-project-$CUSTOM_ENV_CI_PROJECT_ID-concurrent-$CUSTOM_ENV_CI_CONCURRENT_PROJECT_ID-job-$CUSTOM_ENV_CI_JOB_ID"
VM_IMAGE="$VM_IMAGES_PATH/$VM_ID.qcow2"

_get_vm_ip() {
    virsh -q domifaddr "$VM_ID" | awk '{print $4}' | sed -E 's|/([0-9]+)?$||'
}
EOF
            chmod +x /opt/libvirt-driver/base-${runner_name}.sh

            cat > /opt/libvirt-driver/prepare-${runner_name}.sh << 'EOF'
#!/usr/bin/env bash

# Get the script name
script_name_prepare="${0##*/}"

# Strip prefix and ".sh" suffix
desired_value_prepare="${script_name_prepare#*-}"
desired_value_prepare="${desired_value_prepare%.sh}"

# Source variables
source /opt/libvirt-driver/vars-${desired_value_prepare}.sh

currentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${currentDir}/base-${runner_name}.sh # Get variables from base script.

set -eo pipefail

# Cleanup function
cleanup_on_error() {
    /opt/libvirt-driver/cleanup.sh
    exit $SYSTEM_FAILURE_EXIT_CODE
}

# Trap the ERR signal
trap 'cleanup_on_error' ERR

# trap any error, and mark it as a system failure.
trap "exit $SYSTEM_FAILURE_EXIT_CODE" ERR

# Copy base disk to use for Job.
qemu-img create -f qcow2 -b "$BASE_VM_IMAGE" "$VM_IMAGE" -F qcow2

# Install the VM
virt-install \
    --name "$VM_ID" \
    --os-variant rocky8 \
    --disk "$VM_IMAGE" \
    --import \
    --vcpus=2 \
    --ram=14336 \
    --network default \
    --graphics none \
    --noautoconsole

# Wait for VM to get IP
echo 'Waiting for VM to get IP'
for i in $(seq 1 30); do
    VM_IP=$(_get_vm_ip)

    if [ -n "$VM_IP" ]; then
        echo "VM got IP: $VM_IP"
        break
    fi

    if [ "$i" == "30" ]; then
        echo 'Waited 30 seconds for VM to start, exiting...'
        # Inform GitLab Runner that this is a system failure, so it
        # should be retried.
        exit "$SYSTEM_FAILURE_EXIT_CODE"
    fi

    sleep 1s
done

# Wait for ssh to become available
echo "Waiting for sshd to be available"
for i in $(seq 1 30); do
    if ssh -i /home/gitlab-runner/.ssh/id_rsa -o StrictHostKeyChecking=no gitlab-runner@"$VM_IP" >/dev/null 2>/dev/null; then
        break
    fi

    if [ "$i" == "30" ]; then
        echo 'Waited 30 seconds for sshd to start, exiting...'
        # Inform GitLab Runner that this is a system failure, so it
        # should be retried.
        exit "$SYSTEM_FAILURE_EXIT_CODE"
    fi

    sleep 1s
done
EOF
            chmod +x /opt/libvirt-driver/prepare-${runner_name}.sh

            cat > /opt/libvirt-driver/run-${runner_name}.sh << 'EOF'
#!/usr/bin/env bash

# Get the script name
script_name_run="${0##*/}"

# Strip prefix and ".sh" suffix
desired_value_run="${script_name_run#*-}"
desired_value_run="${desired_value_run%.sh}"

# Source variables
source /opt/libvirt-driver/vars-${desired_value_run}.sh

currentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${currentDir}/base-${runner_name}.sh # Get variables from base script.

VM_IP=$(_get_vm_ip)

ssh -i /home/gitlab-runner/.ssh/id_rsa -o StrictHostKeyChecking=no gitlab-runner@"$VM_IP" /bin/bash < "${1}"
if [ $? -ne 0 ]; then
    # Exit using the variable, to make the build as failure in GitLab
    # CI.
    exit "$BUILD_FAILURE_EXIT_CODE"
fi
EOF
            chmod +x /opt/libvirt-driver/run-${runner_name}.sh

            cat > /opt/libvirt-driver/cleanup-${runner_name}.sh << 'EOF'
#!/usr/bin/env bash

# Get the script name
script_name_cleanup="${0##*/}"

# Strip prefix and ".sh" suffix
desired_value_cleanup="${script_name_cleanup#*-}"
desired_value_cleanup="${desired_value_cleanup%.sh}"

# Source variables
source /opt/libvirt-driver/vars-${desired_value_cleanup}.sh

currentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${currentDir}/base-${runner_name}.sh # Get variables from base script.

set -eo pipefail

# Destroy VM.
virsh shutdown "$VM_ID"

# Undefine VM.
virsh undefine "$VM_ID"

# Delete VM disk.
if [ -f "$VM_IMAGE" ]; then
    rm "$VM_IMAGE"
fi
EOF
            chmod +x /opt/libvirt-driver/cleanup-${runner_name}.sh
        done
    fi
done

# Variables for GitLab Runner
GITLAB_SERVER_URL="https://gitlab.com/"

# Concurrent Instances per Runner
CONCURRENT_INSTANCES=4

# Advanced settings
CHECK_INTERVAL=0
SHUTDOWN_TIMEOUT=0
SESSION_TIMEOUT=1800

generate_id() {
    echo $((RANDOM % 90000000 + 10000000))
}

cat > "/etc/gitlab-runner/config.toml" <<EOF
concurrent = $CONCURRENT_INSTANCES
check_interval = $CHECK_INTERVAL
shutdown_timeout = $SHUTDOWN_TIMEOUT

[session_server]
  session_timeout = $SESSION_TIMEOUT

EOF

for runner_key in "${!RUNNERS[@]}"; do
    if [[ $runner_key == *.token ]]; then
        runner_name="${runner_key%.token}"
        runner_token="${RUNNERS[$runner_name.token]}"
        runner_qcow2="${RUNNERS[$runner_name.qcow2]}"
        for i in $(seq 1 $CONCURRENT_INSTANCES); do
            cat >> "/etc/gitlab-runner/config.toml" <<EOF
[[runners]]
  name = "${runner_name}_runner-$(printf "%03d" $i)"
  url = "https://gitlab.com/"
  id = $(generate_id)
  token = "$runner_token"
  token_obtained_at = "$(date +"%Y-%m-%dT%H:%M:%SZ")"
  token_expires_at = "0001-01-01T00:00:00Z"
  executor = "custom"
  builds_dir = "/home/gitlab-runner/builds"
  cache_dir = "/home/gitlab-runner/cache"
  [runners.custom]
    prepare_exec = "/opt/libvirt-driver/prepare-${runner_name}.sh"
    run_exec = "/opt/libvirt-driver/run-${runner_name}.sh"
    cleanup_exec = "/opt/libvirt-driver/cleanup-${runner_name}.sh"

EOF
        done
    fi
done

# Enable GitLab Runner
systemctl enable --force gitlab-runner

cat > /usr/local/bin/cleanup_vms.sh << 'EOF'
#!/bin/bash

VM_LIST=$(LC_ALL=C virsh list --all --name)

for VM in $VM_LIST; do
    virsh destroy $VM       # Forcefully power off VM
    virsh undefine $VM      # Undefine VM

    # Delete associated disk if you wish
    VM_DISK="/var/lib/libvirt/images/${VM}.qcow2"
    if [ -f "$VM_DISK" ]; then
        rm -f "$VM_DISK"
    fi
done

# Delete stale images
rm -f /var/lib/libvirt/images/runner-*
EOF
chmod +x /usr/local/bin/cleanup_vms.sh

cat > /etc/systemd/system/cleanup_vms.service << EOF
[Unit]
Description=Clean up VMs on Boot
After=network.target

[Service]
ExecStart=/usr/local/bin/cleanup_vms.sh

[Install]
WantedBy=multi-user.target
EOF

# Enable VM Cleanup Service
systemctl enable --force cleanup_vms.service

# Allo Libvirt Network in IP Tables
iptables -A FORWARD -m physdev --physdev-is-bridged -j ACCEPT
iptables-save > /etc/sysconfig/iptables

cat > /etc/sysctl.d/99-libvirt.conf << EOF
net.bridge.bridge-nf-call-ip6tables = 0
net.bridge.bridge-nf-call-iptables = 0
net.bridge.bridge-nf-call-arptables = 0 
EOF

# Enable the GitLab Runner service
systemctl enable --force gitlab-runner
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
    type = infra
EOF
%end

%packages
@anaconda-tools
@base-x
@core
@fonts
@hardware-support
@standard
anaconda
anaconda-install-env-deps
anaconda-live
chkconfig
dracut-live
epel-release
initscripts
kernel
kernel-modules
kernel-modules-extra
memtest86+
syslinux
libvirt
virt-install
libguestfs-tools-c
glibc-common
rclone
nginx
fuse
docker
openssh-clients
git
git-lfs
chrony
dnf-automatic
-@admin-tools
-@input-methods
-desktop-backgrounds-basic
-digikam
-gnome-disk-utility
-hplip
-iok
-isdn4k-utils
-k3b
-kdeaccessibility*
-kipi-plugins
-krusader
-ktorrent
-mpage
-scim*
-system-config-printer
-system-config-services
-system-config-users
-xsane
-xsane-gimp

%end

%include lazy-umount.ks
