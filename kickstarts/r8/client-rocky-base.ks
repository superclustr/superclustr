# rocky-live-client-base.ks
#
# Base installation information for Rocky Linux images
#

lang en_US.UTF-8
keyboard us
timezone US/Eastern
selinux --enforcing
firewall --enabled --service=mdns
xconfig --startxonboot
zerombr
clearpart --all
part / --size 51200 --fstype ext4
services --enabled=NetworkManager --disabled=sshd
network --bootproto=dhcp --device=link --activate
rootpw --lock --iscrypted locked
shutdown

%include rocky-repo-epel.ks

%packages
@base-x
@standard
@core
@fonts
@input-methods
@hardware-support

# explicit
kernel
kernel-modules
kernel-modules-extra
memtest86+
anaconda
anaconda-install-env-deps
anaconda-live
@anaconda-tools
python3.11
python3.11-pip
ansible
git

# RHBZ#1242586 - Required for initramfs creation
dracut-live
syslinux

# Anaconda needs all the locales available, just like a DVD installer
glibc-all-langpacks

# This isn't in @core anymore, but livesys still needs it
initscripts
chkconfig

%end

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

if [ -e /run/initramfs/live/\${livedir}/home.img ]; then
  homedev=/run/initramfs/live/\${livedir}/home.img
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

# Even if there isn't gnome, this doesn't hurt.
gsettings set org.gnome.software download-updates 'false' || :

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
echo "localhost" > /etc/hostname

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

# Configure X, allowing user to override xdriver
if [ -n "\$xdriver" ]; then
   cat > /etc/X11/xorg.conf.d/00-xdriver.conf <<FOE
Section "Device"
	Identifier	"Videocard0"
	Driver	"\$xdriver"
EndSection
FOE
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
tmpfs /mnt/home tmpfs defaults,size=512M 0 0
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

%post
# Nvidia DeepOps
git clone --branch release-22.04 --depth 1 https://github.com/NVIDIA/deepops.git /root/deepops
%end

%post --nochroot
# Copying Nvidia DeepOps Patch
cp assets/deepops-release-22.04-rocky-support.patch $INSTALL_ROOT/root/deepops/deepops-release-22.04-rocky-support.patch
%end

%post --nochroot
# Build Initramfs

# Ensure GitLab's authenticity
echo "gitlab.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf" > /root/.ssh/known_hosts

(
git clone --branch main --depth 1 git@gitlab.com:superclustr/initramfs-builder.git
cd initramfs-builder
make
mkdir -p $LIVE_ROOT/pxelinux
cp initrd.img.gz $LIVE_ROOT/pxelinux/initrd.img.gz
cp vmlinuz-* $LIVE_ROOT/pxelinux/vmlinuz0
)

%end

%post
# Patch Rocky Linux Support
(
cd /root/deepops
git apply deepops-release-22.04-rocky-support.patch
)

# Setup DeepOps
/root/deepops/scripts/setup.sh

# Install Kubernetes
ansible-playbook /root/deepops/playbooks/k8s-cluster.yml

# Ensure that NFS is used as a backend for dynamic provisioning of PVCs
ansible-playbook /root/deepops/playbooks/k8s-cluster/nfs-client-provisioner.yml

# Install Prometheus and Grafana
/root/deepops/scripts/k8s/deploy_monitoring.sh

# Install Kubeflow
/root/deepops/scripts/k8s/deploy_kubeflow.sh
%end

%post --erroronfail
# Connect Netdata Monitoring
curl https://my-netdata.io/kickstart.sh > /tmp/netdata-kickstart.sh && sh /tmp/netdata-kickstart.sh --stable-channel --claim-token rP5phC2xRoZkBNJkZsQSbmAJrG3qxI2ZOyL8sOHZKJ0x2Wr0BoZ-6FjFRCIucPyYCbzYlxmXNrfcIkaC5hDANUHHnUn2TvpwnJyEkq6AwUd1QmBzEpIap2rR7Pak_fyugBO-lI8 --claim-rooms 8b3683fd-c4bf-4070-a4de-df6a58856de4 --claim-url https://app.netdata.cloud --dont-wait --dont-start-it

# Overwrite Netdata configuration
cat > /etc/netdata/netdata.conf << EOF
[General]
    run as user = netdata
    page cache size = 32
    dbengine multihost disk space = 256

[host labels]
    type = client
EOF

%end

%post --nochroot
cp $INSTALL_ROOT/usr/share/licenses/*-release/* $LIVE_ROOT/

# This only works on x86_64
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

%include lazy-umount.ks