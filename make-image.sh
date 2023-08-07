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

echo "Building with kickstart file: $kickstart_file and image name: $image_name..."

# Check if image already exists
if [ -z "$(docker images -q $image_name)" ]; then
    echo "Image does not exist. Building it now..."

    # Check if the host system is not x86_64
    if [ $(uname -m) != "x86_64" ]; then
        echo "Host system is not x86_64. Checking for docker buildx plugin..."

        # Make sure you have the docker buildx plugin
        docker buildx version > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "The docker buildx plugin is not installed."
            echo "Please update Docker to the latest version."
            exit 1
        fi

        # Create a new builder
        builder_name=$image_name-builder-$(date +%s)
        echo "Creating a new builder with name: $builder_name..."

        # Create a new builder which gives access to the features of buildx
        docker buildx create --name $builder_name --use

        # Build the Docker image for current platform
        echo "Building the Docker image for current platform..."
        docker buildx build --platform linux/amd64 -t $image_name . --load
    else
        echo "Building the Docker image for x86_64 without buildx..."
        # Build the Docker image for x86_64 without buildx
        docker build -t $image_name .
    fi
else
    echo "Image already exists. Using the existing image..."
fi

# Define the output path on your host
mkdir -p $(pwd)/out
output_path=$(pwd)/out
source_path=$(pwd)/kickstarts

docker run --privileged \
    --platform linux/amd64 \
    --rm \
    --workdir /kickstarts/source \
    --volume $output_path:/kickstarts/out \
    --volume $source_path:/kickstarts/source \
    $image_name \
    /bin/bash -c "
        mkdir -p /root/.ssh && \
        echo \"$private_key\" > /root/.ssh/id_rsa && \
        chmod 400 /root/.ssh/id_rsa && \
        cat /root/.ssh/id_rsa && \
        livecd-creator --verbose -c $kickstart_file -f $image_name && \
        mv $image_name.iso /kickstarts/out"

echo "Done."