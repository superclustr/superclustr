#!/bin/bash -e

usage() {
    echo "Usage: $0 -k <kickstart_file> -i <image_name> -f <format = iso|rootfs|squashfs >"
    echo "Example: $0 -k kickstarts/r8/client-rocky-base.ks -i client-rocky-8.8-x86_64-1.0.0 -p \"\$(cat ~/.ssh/id_rsa)\" -f iso"
    exit 1
}

# Environment
currDir="$(cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)"

while getopts "k:i:f:" opt; do
    case ${opt} in
        k)
            kickstart_file=$OPTARG
            ;;
        i)
            image_name=$OPTARG
            ;;
        f)
            format=$OPTARG
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

if [[ -z "$kickstart_file" || -z "$image_name" ]]; then
    usage
fi

echo "Building with kickstart file: $kickstart_file and image name: $image_name ..."

# List of environment variables to be replaced in the Kickstart files.
# You can extend this list as needed.
ENV_VARS_TO_SUBSTITUTE=(
    "NEXUS_DOMAIN_NAME"
    "NEXUS_DOMAIN_SSL_DHPARAMS"
    "NEXUS_DOMAIN_SSL_CERTIFICATE_PUBLIC_KEY"
    "NEXUS_DOMAIN_SSL_CERTIFICATE_PRIVATE_KEY"
    "NEXUS_HETZNER_STORAGE_BOX_URL"
    "NEXUS_HETZNER_STORAGE_BOX_USERNAME"
    "NEXUS_HETZNER_STORAGE_BOX_PASSWORD"
    "GITLAB_RUNNER_ROCKY_8_TOKEN"
    "GITLAB_RUNNER_ROCKY_9_TOKEN"
    "GITLAB_PXE_SYNC_DAEMON_DEPLOY_TOKEN"
    "GITLAB_PXE_SYNC_DAEMON_DEPLOY_USERNAME"
    "GITLAB_INITRAMFS_BUILDER_DEPLOY_TOKEN"
    "GITLAB_INITRAMFS_BUILDER_DEPLOY_USERNAME"
    # Add more as needed
)

# Path to your original Kickstart files
ORIGINAL_KICKSTART_PATH=$(dirname "$kickstart_file")

# Path to the directory where substituted Kickstart files will be saved
OUTPUT_KICKSTART_PATH="${currDir}/build/kickstarts"

# Create the output directory if it doesn't exist
mkdir -p "$OUTPUT_KICKSTART_PATH"

# Copy the original Kickstart files to the output directory
cp "$ORIGINAL_KICKSTART_PATH"/* "$OUTPUT_KICKSTART_PATH"/

# Loop over each environment variable and substitute its value in the Kickstart files
for env_var in "${ENV_VARS_TO_SUBSTITUTE[@]}"; do
    # Check if the environment variable is set
    if [ -z "${!env_var}" ]; then
        echo "Warning: $env_var is not set!"
        continue # Skip substitution if the environment variable is not set
    fi

    # Substitute the placeholder with the actual value in the Kickstart files using awk
    find "$OUTPUT_KICKSTART_PATH" -name "*.ks" | while read -r ks_file; do
        placeholder="${env_var}_PLACEHOLDER"
        awk -v val="${!env_var}" -v ph="$placeholder" '{ gsub(ph, val); print }' "$ks_file" > "${ks_file}.tmp" && mv "${ks_file}.tmp" "$ks_file"
    done
done

# Now, we can call livemedia-creator with the Kickstart files from the output directory...

function cleanup {
    # Reset back to enforcing mode
    sudo setenforce 1
}
trap cleanup EXIT

# You will need to be in permissive mode temporarily
sudo setenforce 0

# Note: The %include statement as they are not supported by livemedia-creator. 
# All Kickstart files must be flattened using the ksflatten tool before they can be used. 

(
    cd $OUTPUT_KICKSTART_PATH
    ksflatten -c $(basename "$kickstart_file") -o flattened-$(basename "$kickstart_file")
    # FIXME: Livemedia-creator has issues with unmounting after building, we use livecd-creator as alternative
    #sudo livemedia-creator --ks ${OUTPUT_KICKSTART_PATH}/flattened-${kickstart_file} \
    #    --resultdir ${OUTPUT_KICKSTART_PATH}/images \
    #    --project='Rocky Linux' \
    #    --make-iso \
    #    --volid Rocky-Linux-8 \
    #    --iso-only \
    #    --iso-name ${image_name}.iso \
    #    --releasever=8 \
    #    --nomacboot \
    #    --no-virt
    sudo livecd-creator --config ${OUTPUT_KICKSTART_PATH}/flattened-$(basename "$kickstart_file") \
        --fslabel ${image_name}
   
)

mkdir -p ${OUTPUT_KICKSTART_PATH}/images   

case "$format" in
    rootfs)
        echo "Exporting as rootfs..."

        mkdir -p /tmp/iso_mount /tmp/squashfs_mount
        sudo mount -o loop ${OUTPUT_KICKSTART_PATH}/${image_name}.iso /tmp/iso_mount
        sudo mount -o loop /tmp/iso_mount/LiveOS/squashfs.img /tmp/squashfs_mount

        sudo ls /tmp/iso_mount/pxelinux

        sudo tar -czvf ${image_name}.tar.gz \
            /tmp/squashfs_mount/LiveOS/rootfs.img \
            /tmp/iso_mount/pxelinux/initrd.img.gz \
            /tmp/iso_mount/pxelinux/vmlinuz0
        
        mv ${image_name}.tar.gz ${OUTPUT_KICKSTART_PATH}/images
        
        sudo umount /tmp/iso_mount
        sudo umount /tmp/squashfs_mount

        echo -e "Exported as rootfs to ${OUTPUT_KICKSTART_PATH}/images/${image_name}.tar.gz"
        ;;
    iso)
        echo "Exporting as iso..."

        mv ${OUTPUT_KICKSTART_PATH}/${image_name}.iso ${OUTPUT_KICKSTART_PATH}/images

        echo -e "Exported as iso to ${OUTPUT_KICKSTART_PATH}/images/${image_name}.iso"
        ;;
    squashfs)
        echo "Exporting as squashfs..."

        mkdir -p /tmp/iso_mount
        sudo mount -o loop ${OUTPUT_KICKSTART_PATH}/${image_name}.iso /tmp/iso_mount
        cp /tmp/iso_mount/LiveOS/squashfs.img ${OUTPUT_KICKSTART_PATH}/images/${image_name}.img
        sudo umount /tmp/iso_mount

        echo -e "Exported as squashfs to ${OUTPUT_KICKSTART_PATH}/images/${image_name}.img"
        ;;
    *)
        echo "Invalid option: $format" 1>&2
        usage
        ;;
esac

echo "Done."