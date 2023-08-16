#!/bin/bash -e

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
    # Add more as needed
)

# Path to your original Kickstart files
ORIGINAL_KICKSTART_PATH="kickstarts"

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
    # Reset Private key
    if [ -n "${private_key}" ]; then
        if [[ -e "~/.ssh/id_rsa.bak" ]]; then
            mv "~/.ssh/id_rsa.bak" "~/.ssh/id_rsa"
            chmod 400 ~/.ssh/id_rsa
        fi
    fi
    # Reset back to enforcing mode
    sudo setenforce 1
}
trap cleanup EXIT

# You will need to be in permissive mode temporarily
sudo setenforce 0

if [ -n "${private_key}" ]; then
    # Replace Private key
    mkdir -p ~/.ssh
    if [[ -e "~/.ssh/id_rsa" ]]; then
        mv "~/.ssh/id_rsa" "~/.ssh/id_rsa.bak"
    fi
    echo \"${private_key}\" > ~/.ssh/id_rsa
    chmod 400 ~/.ssh/id_rsa
fi

# Create tmp directory
mkdir -p ${currDir}/lmc_tmp

# Note: The %include statement as they are not supported by livemedia-creator. 
# All Kickstart files must be flattened using the ksflatten tool before they can be used. 

(
    cd $OUTPUT_KICKSTART_PATH
    ksflatten -c ${kickstart_file} -o flattened-${kickstart_file}
    sudo livemedia-creator --ks ${OUTPUT_KICKSTART_PATH}/flattened-${kickstart_file} \
        --no-virt \
        --resultdir ${OUTPUT_KICKSTART_PATH}/images \
        --project='Rocky Linux' \
        --make-iso \
        --volid Rocky-Linux-8 \
        --iso-only \
        --iso-name ${image_name}.iso \
        --releasever=8 \
        --nomacboot \
        --tmp ${currDir}/lmc_tmp
)

echo "Done."