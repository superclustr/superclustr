#!/bin/bash -e

# Define the image name
image_name="rockylinux-base"

# Make sure you have the docker buildx plugin
docker buildx version > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "The docker buildx plugin is not installed."
    echo "Please update Docker to the latest version."
    exit 1
fi

# Create a new builder which gives access to the features of buildx
docker buildx create --name mybuilder --use

# Build the Docker image for linux/amd64
docker buildx build --platform linux/amd64 -t $image_name . --load

# Define the output path on your host
mkdir -p $(pwd)/out
output_path=$(pwd)/out

# Build Rocky Live Node
docker run --privileged --platform linux/amd64 \
    -v $output_path:/kickstarts/out $image_name /bin/bash \
    -c "livecd-creator --verbose -c rocky-live-node-base.ks -f rocky-live-base && mv rocky-live-node-base.iso out"

# Build Rocky Live PXE
docker run --privileged --platform linux/amd64 \
    -v $output_path:/kickstarts/out $image_name /bin/bash \
    -c "livecd-creator --verbose -c rocky-live-pxe-base.ks -f rocky-live-base && mv rocky-live-pxe-base.iso out"