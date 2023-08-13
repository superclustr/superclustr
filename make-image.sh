#!/bin/bash -e

usage() {
    echo "Usage: $0 -k <kickstart_file> -i <image_name> -p <private_key>"
    echo "Example: $0 -k rocky-live-client-base.ks -i my-rocky-live-client -p \"\$(cat ~/.ssh/id_rsa)\""
    exit 1
}

while getopts "k:i:p:" opt; do
    case ${opt} in
        k)
            kickstart_file=$OPTARG
            ;;
        i)
            image_name=$OPTARG
            ;;
        p)
            private_key=$OPTARG
            ;;
        \?)
            echo "Invalid option: $OPTARG" 1>&2
            usage
            ;;
        :)
            echo "Invalid option: $OPTARG requires an argument" 1>&2
            usage
            ;;
    esac
done
shift $((OPTIND -1))

if [[ -z "$kickstart_file" || -z "$image_name" || -z "$private_key" ]]; then
    usage
fi

# Define paths
output_path=$(pwd)/build
assets_path=$(pwd)/assets
kickstarts_path=$(pwd)/kickstarts
base_vm_image="$(pwd)/images/Rocky-8-GenericCloud.latest.x86_64.qcow2" # Replace with the path to your template VM
vm_image="${image_name}.qcow2"

# Clone the base VM image
cp $base_vm_image $vm_image

# Script to run inside the VM
cat > script_inside_vm.sh <<EOL
#!/bin/bash
yum install -y openssh-server
systemctl start sshd
systemctl enable sshd
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
systemctl restart sshd
mkdir -p /root/.ssh
echo "$private_key" > /root/.ssh/id_rsa
chmod 400 /root/.ssh/id_rsa
cd /mnt/kickstarts
livemedia-creator --ks $kickstart_file \
    --no-virt \
    --resultdir /var/lmc \
    --project='Rocky Linux' \
    --make-iso \
    --volid Rocky-Workstation-8 \
    --iso-only \
    --iso-name $image_name.iso \
    --releasever=8 \
    --nomacboot && \
    mv /var/lmc/$image_name.iso /mnt/out
EOL
chmod +x script_inside_vm.sh

# Start VM and run the script inside
virt-install --name $image_name \
             --memory 2048 \
             --vcpus 2 \
             --disk path=$vm_image \
             --import \
             --os-type linux \
             --os-variant rhel8 \
             --network default \
             --noautoconsole \
             --filesystem $kickstarts_path,/mnt/kickstarts \
             --filesystem $assets_path,/mnt/assets \
             --filesystem $output_path,/mnt/out \
             --filesystem $(pwd)/script_inside_vm.sh,/mnt/script_inside_vm.sh \
             --init /mnt/script_inside_vm.sh

# NOTE: At this point, you might want to add a delay or a check to ensure the VM has fully started up and the SSH server is running.
sleep 120 # wait for 2 minutes. Adjust as needed.

# Assuming your VM gets an IP address from the default DHCP, you should try to find out this IP, replace VM_IP with the appropriate method to retrieve it
# Get the VM's IP address
VM_IP=$(virsh domifaddr $image_name | grep ipv4 | awk '{print $4}' | cut -d'/' -f1)

# Check if we got an IP
if [[ -z "$VM_IP" ]]; then
    echo "Failed to retrieve the VM's IP address."
    exit 1
fi

# Copy the generated ISO from VM to host
scp -i ~/.ssh/id_rsa root@$VM_IP:/mnt/out/$image_name.iso $output_path/

# Optionally, you can shut down the VM or perform other cleanup tasks here.
