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
part / --size 10240 --fstype ext4 --fsoptions="ro"
services --enabled=NetworkManager,ModemManager --disabled=sshd
network --bootproto=dhcp --device=link --nameserver=8.8.8.8,8.8.4.4 --activate
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

%post --log=/root/ks-post.log
# Make sure dracut will embed the whole system
cat > /etc/dracut.conf.d/embed-whole-os.conf <<EOF
hostonly="no"
EOF

# Now rebuild initramfs with dracut to include the entire OS
dracut --force --no-hostonly

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

# Disable network service here, as doing it in the services line
# fails due to RHBZ #1369794 - the error is expected
/sbin/chkconfig network off

# Remove machine-id on generated images
rm -f /etc/machine-id
touch /etc/machine-id

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
cp /kickstarts/assets/deepops-release-22.04-rocky-support.patch $INSTALL_ROOT/root/deepops/deepops-release-22.04-rocky-support.patch
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
curl https://my-netdata.io/kickstart.sh > /tmp/netdata-kickstart.sh && sh /tmp/netdata-kickstart.sh --stable-channel --claim-token rP5phC2xRoZkBNJkZsQSbmAJrG3qxI2ZOyL8sOHZKJ0x2Wr0BoZ-6FjFRCIucPyYCbzYlxmXNrfcIkaC5hDANUHHnUn2TvpwnJyEkq6AwUd1QmBzEpIap2rR7Pak_fyugBO-lI8 --claim-rooms 8b3683fd-c4bf-4070-a4de-df6a58856de4 --claim-url https://app.netdata.cloud --dont-start-it

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
