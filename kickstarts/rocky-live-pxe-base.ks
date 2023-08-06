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

# add liveinst.desktop to favorites menu
mkdir -p /home/liveuser/.config/
cat > /home/liveuser/.config/kickoffrc << MENU_EOF
[Favorites]
FavoriteURLs=/usr/share/applications/firefox.desktop,/usr/share/applications/org.kde.dolphin.desktop,/usr/share/applications/systemsettings.desktop,/usr/share/applications/org.kde.konsole.desktop,/usr/share/applications/liveinst.desktop
MENU_EOF

# show liveinst.desktop on desktop and in menu
sed -i 's/NoDisplay=true/NoDisplay=false/' /usr/share/applications/liveinst.desktop

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

%post
# Install Cobbler PXE Server
dnf install -y cobbler cobbler-web
systemctl enable --force cobblerd.service
systemctl start cobblerd.service
%end

%post --erroronfail
pip3 install requests python-gnupg tkinter

cat <<EOF > /usr/local/lib/synchronize.py
import os
import getpass
import json
import requests
import gnupg
import time
import subprocess
from tkinter import Tk, Label, Entry, Button, PhotoImage
import urllib.request
import base64
import webbrowser

# Initialize GPG
gpg = gnupg.GPG()

# GitHub repo details
REPO_OWNER = 'EXTERNAL_REPO_OWNER'
REPO_NAME = 'EXTERNAL_REPO_NAME'

# File paths
TARGET_DIR = os.path.expanduser('~') + '/assets'
SECRET_FILE = os.path.expanduser('~') + '/.github_pat'

# Cobbler mount point
MOUNT_POINT = "/mnt/bootiso"

def encrypt_and_store_pat():
    def on_ok():
        pat = pat_entry.get()
        password = pass_entry.get()
        encrypted_data = gpg.encrypt(pat, recipients=None, symmetric='AES256', passphrase=password)
        with open(SECRET_FILE + '.gpg', 'w') as f:
            f.write(str(encrypted_data))
        root.quit()

    root = Tk()
    root.title("PAT Input")

    # Set background to dark
    root.configure(bg='black')

    # Download logo and create PhotoImage
    url = "https://uploads-ssl.webflow.com/647fb05633281b6048f97203/64ab3ba3752f2e90198fa852_supercluastr-logo.svg"
    image_byt = urllib.request.urlopen(url).read()
    image_b64 = base64.encodestring(image_byt)
    photo = PhotoImage(data=image_b64)

    # Add logo to GUI
    logo_label = Label(root, image=photo)
    logo_label.pack()

    # Add description
    desc_label = Label(root, text="Please enter your GitHub PAT. It will be stored securely and used to download private GitHub repository assets.")
    desc_label.pack()

    # Add PAT input field
    pat_label = Label(root, text="GitHub PAT:")
    pat_label.pack()
    pat_entry = Entry(root)
    pat_entry.pack()

    # Add password input field
    pass_label = Label(root, text="Password for encryption:")
    pass_label.pack()
    pass_entry = Entry(root, show="*")
    pass_entry.pack()

    # Add OK button
    ok_button = Button(root, text="OK", command=on_ok)
    ok_button.pack()

    # Add documentation link
    doc_label = Label(root, text="For more information, see the documentation at superclustr.net/docs/setup-pxe-server.", cursor="hand2")
    doc_label.pack()
    doc_label.bind("<Button-1>", lambda e: webbrowser.open_new("http://superclustr.net/docs/setup-pxe-server"))

    root.mainloop()

def get_pat():
    with open(SECRET_FILE + '.gpg', 'r') as f:
        encrypted_data = f.read()
    return str(gpg.decrypt(encrypted_data, passphrase=getpass.getpass('Enter your password to decrypt PAT: ')))

def add_to_cobbler(iso_file):
    distro_id = iso_file.rsplit("/", 1)[-1].rsplit(".", 1)[0]  # ISO file name without extension
    # Mount the ISO
    subprocess.run(['mount', '-o', 'loop', iso_file, MOUNT_POINT], check=True)
    # Add the distribution to Cobbler
    subprocess.run(['cobbler', 'distro', 'add', '--name=' + distro_id, '--kernel=' + MOUNT_POINT + '/images/pxeboot/vmlinuz', '--initrd=' + MOUNT_POINT + '/images/pxeboot/initrd.img'], check=True)
    # Add the profile to Cobbler
    subprocess.run(['cobbler', 'profile', 'add', '--name=' + distro_id, '--distro=' + distro_id], check=True)
    # Unmount the ISO
    subprocess.run(['umount', MOUNT_POINT], check=True)

def download_latest_release_assets(pat):
    headers = {
        'Authorization': f'token {pat}',
        'Accept': 'application/vnd.github.v3+json',
    }
    latest_release = requests.get(f'https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/releases/latest', headers=headers).json()
    assets_url = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/releases/tags/{latest_release['tag_name']}/assets"
    assets = requests.get(assets_url, headers=headers).json()
    for asset in assets:
        download_url = asset['browser_download_url']
        response = requests.get(download_url, headers=headers, stream=True)
        iso_file = TARGET_DIR + '/' + asset['name']
        with open(iso_file, 'wb') as f:
            f.write(response.content)
        add_to_cobbler(iso_file)  # add the downloaded ISO to Cobbler

if not os.path.isfile(SECRET_FILE + '.gpg'):
    encrypt_and_store_pat()

while True:
    pat = get_pat()
    download_latest_release_assets(pat)
    time.sleep(3600)  # check every hour
EOF

cat <<EOF > /etc/systemd/system/synchronize.service
[Unit]
Description=Github PAT and ISO download service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/lib/synchronize.py
Restart=on-failure
RestartSec=30s

[Install]
WantedBy=multi-user.target
EOF

systemctl enable --force synchronize.service
%end

%include lazy-umount.ks