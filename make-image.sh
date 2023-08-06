#!/bin/bash -e

usage() {
    echo "Usage: $0 -k <kickstart_file> -i <image_name> [-d | -n]"
    echo "Example: $0 -k rocky-live-node-base.ks -i my-rocky-live -d"
    echo "Use -d to force Docker build. Use -n to force host build."
    exit 1
}

force_docker_build=0
force_no_docker_build=0

while getopts "k:i:dn" opt; do
    case ${opt} in
        k)
            kickstart_file=$OPTARG
            ;;
        i)
            image_name=$OPTARG
            ;;
        d)
            force_docker_build=1
            ;;
        n)
            force_no_docker_build=1
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

if [[ $force_docker_build -eq 1 && $force_no_docker_build -eq 1 ]]; then
    echo "You cannot force both Docker and no-Docker build."
    exit 1
fi

echo "Building with kickstart file: $kickstart_file and image name: $image_name..."

# Get the operating system and machine architecture
os=$(uname -s)
arch=$(uname -m)

# If the operating system is Linux and architecture is amd64
if [[ $os == "Linux" ]] && [[ $arch == "x86_64" ]] && [[ $force_docker_build -eq 0 ]]; then
    echo "Running on Linux. Executing commands directly on the host system..."

    # Installing build dependencies
    dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm \
    && dnf config-manager --set-enabled epel \
    && dnf -y update \
    && dnf install -y livecd-tools dracut-network \
    && dnf clean all \
    && rm -rf /var/cache/dnf

    # Define the output path on your host
    mkdir -p $(pwd)/out
    output_path=$(pwd)/out

    echo "Building Image..."
    cd $(pwd)/kickstarts
    livecd-creator --verbose -c $kickstart_file -f $image_name

    echo "Moving ISO to output directory..."
    mv $image_name.iso $output_path

    echo "Done."

elif [[ $force_no_docker_build -eq 0 ]]; then
    echo "Not running on Linux or Docker build forced. Executing commands in Docker..."

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

    # Note: This might fail if the host file system does not support the 'pquota' mount option.
    # Please refer to https://stackoverflow.com/a/57248363/8413942 on how to enable 'pquota' if you encounter an error with this option.
    docker run --privileged --storage-opt size=7G \
        --platform linux/amd64 --rm \
        --workdir /kickstarts/source \
        --volume $output_path:/kickstarts/out \
        --volume $source_path:/kickstarts/source \
        $image_name \
        /bin/bash -c "livecd-creator --verbose -c $kickstart_file -f $image_name && mv $image_name.iso /kickstarts/out"

    echo "Done."
fi
