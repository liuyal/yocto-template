#!/bin/bash

# Yocto/OpenEmbedded Build Environment Setup - Step 1
# This script creates the workspace layout and all initial project files
# Based on: https://github.com/your-repo/yocto-template

set -e  # Exit on error

PROJECT_ROOT=~/yocto-project

echo "=========================================="
echo "Step 1: Create Workspace & Project Files"
echo "=========================================="
echo ""

echo "Creating workspace directories..."

# Create main workspace directories
mkdir -p "$PROJECT_ROOT"/{docker,bitbake,openembedded-core,downloads,sstate-cache}

# Create meta-project directories with all subdirectories
mkdir -p "$PROJECT_ROOT"/meta-project/{conf/distro,conf/machine,recipes-apps/hello/files,recipes-core/images,recipes-kernel}

# Create build configuration directory
mkdir -p "$PROJECT_ROOT"/build/conf

cd "$PROJECT_ROOT"

echo "Changed to: $PROJECT_ROOT"
echo ""

echo "Creating Docker container configuration..."
echo "  → docker/Dockerfile"
cat <<'EOF' > docker/Dockerfile
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    gawk \
    wget \
    git \
    diffstat \
    unzip \
    texinfo \
    gcc \
    build-essential \
    chrpath \
    socat \
    cpio \
    python3 \
    python3-pip \
    python3-pexpect \
    xz-utils \
    debianutils \
    iputils-ping \
    python3-git \
    python3-jinja2 \
    libegl1 \
    libsdl1.2-dev \
    pylint \
    xterm \
    file \
    locales \
    sudo \
    vim \
    bc \
    rsync \
    zstd \
    lz4 \
    qemu-system-x86 \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

ARG USER_ID=1000
ARG GROUP_ID=1000
ARG USER_NAME=builder

RUN EXISTING_GROUP="$(getent group $GROUP_ID | cut -d: -f1)"; \
    if [ -n "$EXISTING_GROUP" ] && [ "$EXISTING_GROUP" != "$USER_NAME" ]; then \
        groupmod -n $USER_NAME "$EXISTING_GROUP"; \
    elif [ -z "$EXISTING_GROUP" ]; then \
        groupadd -g $GROUP_ID $USER_NAME; \
    fi && \
    EXISTING_USER="$(getent passwd $USER_ID | cut -d: -f1)"; \
    if [ -n "$EXISTING_USER" ] && [ "$EXISTING_USER" != "$USER_NAME" ]; then \
        usermod -l $USER_NAME -d /home/$USER_NAME -m "$EXISTING_USER"; \
    elif [ -z "$EXISTING_USER" ]; then \
        useradd -m -u $USER_ID -g $GROUP_ID $USER_NAME; \
    fi && \
    echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER $USER_NAME

WORKDIR /workspace
EOF

echo "  → docker/run.sh"
cat <<'EOF' > docker/run.sh
#!/bin/bash

docker run \
    --rm \
    -it \
    -v $(pwd):/workspace \
    -v $(pwd)/downloads:/workspace/downloads \
    -v $(pwd)/sstate-cache:/workspace/sstate-cache \
    project-yocto:1.0 \
    /bin/bash
EOF
chmod +x docker/run.sh

echo ""
echo "Creating environment configuration..."
echo "  → env.sh"
cat <<'EOF' > env.sh
#!/bin/bash

export PROJ_ROOT=/workspace

export PATH=$PROJ_ROOT/bitbake/bin:$PATH
export PATH=$PROJ_ROOT/openembedded-core/scripts:$PATH

export BBPATH=$PROJ_ROOT/build
EOF

echo ""
echo "Creating BitBake layer configuration..."
echo "  → meta-project/conf/layer.conf"
cat <<'EOF' > meta-project/conf/layer.conf
BBPATH .= ":${LAYERDIR}"

BBFILES += "${LAYERDIR}/recipes-*/*/*.bb"

BBFILE_COLLECTIONS += "project"

BBFILE_PATTERN_project := "^${LAYERDIR}/"

BBFILE_PRIORITY_project = "100"

LAYERSERIES_COMPAT_project = "scarthgap"
EOF

echo "Creating build system configuration..."
echo "  → build/conf/bblayers.conf"
cat <<'EOF' > build/conf/bblayers.conf
BBLAYERS ?= " \
    /workspace/openembedded-core/meta \
    /workspace/meta-project \
"
EOF

echo "  → build/conf/local.conf"
cat <<'EOF' > build/conf/local.conf
MACHINE = "qemux86-64"

DISTRO = "project"

DL_DIR = "/workspace/downloads"

SSTATE_DIR = "/workspace/sstate-cache"

TMPDIR = "${TOPDIR}/tmp"

TCLIBCAPPEND = ""

PACKAGE_CLASSES = "package_rpm"

BB_NUMBER_THREADS = "8"
PARALLEL_MAKE = "-j8"

# Disable the network connectivity sanity check (fails in restricted/offline environments)
CONNECTIVITY_CHECK_URIS = ""
EOF

echo ""
echo "Creating distribution and machine configurations..."
echo "  → meta-project/conf/distro/project.conf"
cat <<'EOF' > meta-project/conf/distro/project.conf
DISTRO_NAME = "Project Distribution"

DISTRO_VERSION = "1.0"

TARGET_VENDOR = "-project"

PACKAGE_CLASSES ?= "package_rpm"
EOF

echo "  → meta-project/conf/machine/qemux86-64.conf"
cat <<'EOF' > meta-project/conf/machine/qemux86-64.conf
require conf/machine/include/qemuboot-x86.inc

TARGET_ARCH = "x86_64"
EOF

echo ""
echo "Creating recipe files..."
echo "  → meta-project/recipes-apps/hello/files/hello.c"
cat <<'EOF' > meta-project/recipes-apps/hello/files/hello.c
#include <stdio.h>

int main()
{
    printf("Hello from Yocto\n");
    return 0;
}
EOF

echo "  → meta-project/recipes-apps/hello/hello.bb"
cat <<'EOF' > meta-project/recipes-apps/hello/hello.bb
SUMMARY = "Hello World"

LICENSE = "MIT"

LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://hello.c"

S = "${WORKDIR}"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} hello.c -o hello
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 hello ${D}${bindir}
}
EOF

echo "  → meta-project/recipes-core/images/project-image.bb"
cat <<'EOF' > meta-project/recipes-core/images/project-image.bb
SUMMARY = "Project Image"

LICENSE = "MIT"

inherit core-image

IMAGE_INSTALL += "hello"

IMAGE_NAME_SUFFIX = ""

IMAGE_LINK_NAME = "${IMAGE_BASENAME}-${MACHINE}"

IMAGE_FEATURES += "debug-tweaks"
EOF

echo ""
echo "=========================================="
echo "✓ Step 1 Complete!"
echo "=========================================="
echo ""
echo "Workspace created at: $PROJECT_ROOT"
echo ""
echo "Directory structure:"
tree -L 2 "$PROJECT_ROOT" 2>/dev/null || find "$PROJECT_ROOT" -type d | head -20
echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "Step 2: Build the Docker image"
echo "  Run this on your host machine:"
echo "  docker build \\"
echo "    --build-arg USER_ID=\$(id -u) \\"
echo "    --build-arg GROUP_ID=\$(id -g) \\"
echo "    --build-arg USER_NAME=\$(whoami) \\"
echo "    -t project-yocto:1.0 docker/"
echo ""
echo "Step 3: Launch the container"
echo "  ./docker/run.sh"
echo ""
echo "Step 4-5: Inside the container, clone repositories"
echo "  (Run these commands inside the container)"
echo "  git clone -b 2.8 https://github.com/openembedded/bitbake.git"
echo "  git clone -b scarthgap https://github.com/openembedded/openembedded-core.git"
echo "  source env.sh"
echo ""

