# Use the official Rocky Linux 8 image as base
FROM rockylinux/rockylinux:8

USER root

# Install necessary packages
RUN dnf install -y dracut-network python2 git make

# Link python2 to python for convenience
RUN ln -s /usr/bin/python2 /usr/bin/python

# Build livecd-tools-034 from source
# Bug https://bugzilla.redhat.com/show_bug.cgi?id=509427
RUN git clone --branch livecd-tools-034 https://github.com/livecd-tools/livecd-tools.git && \
        cd livecd-tools && \
        make install

# Kickstart files are expected to be mounted at via docker volumes
# Only use this if you don't trust your docker volumes
# COPY kickstarts .