#!/bin/bash -e

# Logging 
set -x

usage() {
    echo "Usage: $0 -k <kickstart_file> -i <image_name> -p <private_key>"
    echo "Example: $0 -k kickstarts/rocky-live-client-base.ks -i my-rocky-live-client -p \"\$(cat ~/.ssh/id_rsa)\""
    exit 1
}

# Environment
currDir="$(cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)"

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

echo "Building with kickstart file: $kickstart_file and image name: $image_name ..."

function cleanup {
    # Reset back to enforcing mode
    sudo setenforce 1
}
trap cleanup EXIT

# You will need to be in permissive mode temporarily
sudo setenforce 0

mkdir -p /root/.ssh
echo \"${private_key}\" > /root/.ssh/id_rsa
chmod 400 /root/.ssh/id_rsa

livemedia-creator --ks ${kickstart_file} \
    --no-virt \
    --resultdir $currDir/build \
    --project='Rocky Linux' \
    --make-iso \
    --volid Rocky-Linux-8 \
    --iso-only \
    --iso-name ${image_name}.iso \
    --releasever=8 \
    --nomacboot

echo "Done."