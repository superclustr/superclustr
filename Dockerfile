# Use the official Rocky Linux 8 image as base
FROM rockylinux/rockylinux:8

USER root

# Define working directory
WORKDIR /kickstarts

# Install necessary packages
RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm \
    && dnf config-manager --set-enabled epel \
    && dnf -y update \
    && dnf install -y livecd-tools dracut-network \
    && dnf clean all \
    && rm -rf /var/cache/yum

# Copy kickstart files into Docker image
COPY kickstarts .