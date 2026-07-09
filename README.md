# Yocto/OpenEmbedded Build Environment From Scratch Using Docker

## Overview

This guide describes how to create a Yocto/OpenEmbedded build environment completely from scratch without using:

- Poky
- oe-init-build-env
- Existing build templates

The build system will be based on:

- BitBake
- OpenEmbedded-Core (OE-Core)
- Custom metadata layers
- Docker containerized build environment

This approach provides:

- Full understanding of the Yocto architecture
- Reproducible Docker builds
- CI/CD friendly workflows
- Complete control of layer structure and configuration


# Architecture
```text
Host Machine
│
├── Docker Engine
│
└── yocto-project/
    │
    ├── docker/
    │   ├── Dockerfile
    │   └── run.sh
    │
    ├── bitbake/
    ├── openembedded-core/
    ├── meta-project/
    ├── build/
    ├── downloads/
    └── sstate-cache/
```

Container Layout:
```text
+------------------------------------------+
| Host machine                             |
|                                          |
| bitbake                                  |
| openembedded-core                        |
| meta-project                             |
| build                                    |
| downloads                                |
| sstate-cache                             |
+------------------------------------------+
```

# Step 1: Create Workspace & Project Files

Initial directory structure:
```text
yocto-project/
│
├── docker/
├── bitbake/
├── openembedded-core/
├── meta-project/
├── build/
├── downloads/
└── sstate-cache/
```

Save the following as `setup-workspace.sh`. It creates the entire directory layout and every file needed (Dockerfile, launch script, env script, custom layer, build configuration, and the Hello World app/recipes) in a single pass:

```bash
cat <<'SCRIPT' > setup-workspace.sh
#!/bin/bash
set -e

PROJECT_ROOT=~/yocto-project

# Workspace layout
mkdir -p "$PROJECT_ROOT"/{docker,bitbake,openembedded-core,downloads,sstate-cache}
mkdir -p "$PROJECT_ROOT"/meta-project/{conf/distro,conf/machine,recipes-apps/hello/files,recipes-core/images,recipes-kernel}
mkdir -p "$PROJECT_ROOT"/build/conf
cd "$PROJECT_ROOT"

# docker/Dockerfile
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

# docker/run.sh
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

# env.sh (sourced inside the container)
cat <<'EOF' > env.sh
#!/bin/bash

export PROJ_ROOT=/workspace

export PATH=$PROJ_ROOT/bitbake/bin:$PATH

export BBPATH=$PROJ_ROOT/build
EOF

# meta-project/conf/layer.conf
cat <<'EOF' > meta-project/conf/layer.conf
BBPATH .= ":${LAYERDIR}"

BBFILES += "${LAYERDIR}/recipes-*/*/*.bb"

BBFILE_COLLECTIONS += "project"

BBFILE_PATTERN_project := "^${LAYERDIR}/"

BBFILE_PRIORITY_project = "100"

LAYERSERIES_COMPAT_project = "scarthgap"
EOF

# build/conf/bblayers.conf
cat <<'EOF' > build/conf/bblayers.conf
BBLAYERS ?= " \
    /workspace/openembedded-core/meta \
    /workspace/meta-project \
"
EOF

# build/conf/local.conf
cat <<'EOF' > build/conf/local.conf
MACHINE = "qemux86-64"

DISTRO = "project"

DL_DIR = "/workspace/downloads"

SSTATE_DIR = "/workspace/sstate-cache"

TMPDIR = "${TOPDIR}/tmp"

PACKAGE_CLASSES = "package_rpm"

BB_NUMBER_THREADS = "8"
PARALLEL_MAKE = "-j8"

# Disable the network connectivity sanity check (fails in restricted/offline environments)
CONNECTIVITY_CHECK_URIS = ""
EOF

# meta-project/conf/distro/project.conf
cat <<'EOF' > meta-project/conf/distro/project.conf
DISTRO_NAME = "Project Distribution"

DISTRO_VERSION = "1.0"

TARGET_VENDOR = "-project"

PACKAGE_CLASSES ?= "package_rpm"
EOF

# meta-project/conf/machine/qemux86-64.conf
cat <<'EOF' > meta-project/conf/machine/qemux86-64.conf
require conf/machine/include/qemuboot-x86.inc

TARGET_ARCH = "x86_64"
EOF

# meta-project/recipes-apps/hello/files/hello.c
cat <<'EOF' > meta-project/recipes-apps/hello/files/hello.c
#include <stdio.h>

int main()
{
    printf("Hello from Yocto\n");
    return 0;
}
EOF

# meta-project/recipes-apps/hello/hello.bb
cat <<'EOF' > meta-project/recipes-apps/hello/hello.bb
SUMMARY = "Hello World"

LICENSE = "MIT"

SRC_URI = "file://hello.c"

S = "${WORKDIR}"

do_compile() {
    ${CC} hello.c -o hello
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 hello ${D}${bindir}
}
EOF

# meta-project/recipes-core/images/project-image.bb
cat <<'EOF' > meta-project/recipes-core/images/project-image.bb
SUMMARY = "Project Image"

LICENSE = "MIT"

inherit core-image

IMAGE_INSTALL += "hello"
EOF

echo "Workspace created at $PROJECT_ROOT"
SCRIPT

chmod +x setup-workspace.sh
```

Run it:

```bash
./setup-workspace.sh
cd ~/yocto-project
```

# Step 2: Build the Docker Image

Build the Docker image, passing your host user/group IDs and username so the container's user matches your host account and owns bind-mounted files on `/workspace`:
```bash
docker build \
    --build-arg USER_ID=$(id -u) \
    --build-arg GROUP_ID=$(id -g) \
    --build-arg USER_NAME=$(whoami) \
    -t project-yocto:1.0 docker/
```

# Step 3: Launch the Container

```bash
./docker/run.sh
```

This drops you into a shell inside the container at `/workspace`. **Run all following steps inside this container shell**, not on the host.

# Step 4: Clone Required Repositories From GitHub

`openembedded-core` (and other OE/Yocto layers) use release **codename** branches (e.g. `scarthgap`), but the standalone `bitbake` repository uses **numeric version** branches instead. They do NOT share the same branch name. The mapping between recent releases is:

| Release codename | Yocto version | BitBake branch |
|---|---|---|
| kirkstone   | 4.0 (LTS) | 2.0 |
| langdale    | 4.1       | 2.2 |
| mickledore  | 4.2       | 2.4 |
| nanbield    | 4.3       | 2.6 |
| scarthgap   | 5.0 (LTS) | 2.8 |

You can always confirm the exact branch/tag available with:

```bash
git ls-remote --heads https://github.com/openembedded/bitbake.git | grep 2.8
```

Clone using the matching branches (example using the Scarthgap LTS release). The `bitbake/` and `openembedded-core/` directories were already created in Step 1 and are bind-mounted into `/workspace`, so clone directly into them:
```bash
git clone -b 2.8 https://github.com/openembedded/bitbake.git
git clone -b scarthgap https://github.com/openembedded/openembedded-core.git
```

# Step 5: Load Environment & Verify BitBake

```bash
source env.sh
```

Verify BitBake:

```bash
bitbake --version
```

# Step 6: Verify Layer Discovery

Display configured layers:

```bash
bitbake-layers show-layers
```

Expected output:

```text
layer                 priority
------------------------------
openembedded-core     5
project               100
```

Show recipes:

```bash
bitbake-layers show-recipes
```

# Step 7: Build the Application

Build the hello package:

```bash
bitbake hello
```

Outputs are generated under:

```text
build/tmp/work/
```

Packages appear under:

```text
build/tmp/deploy/rpm/
```

or

```text
build/tmp/deploy/ipk/
```

depending on package format.

# Step 8: Build the Image

Build the image:

```bash
bitbake project-image
```

Output location:

```text
build/tmp/deploy/images/qemux86-64/
```

Example artifacts:

```text
bzImage
project-image.rootfs.ext4
project-image.rootfs.tar.gz
```

# Step 9: Create a Kernel Recipe

Create:

```text
meta-project/
└── recipes-kernel/
    └── linux/
        └── linux-project.bb
```

Example:

```bitbake
SUMMARY = "Custom Linux Kernel"

LICENSE = "GPLv2"

SRC_URI = "git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"

SRCREV = "HEAD"

inherit kernel
```

# Step 10: Recommended Production Layer Layout

```text
yocto-project/
│
├── docker/
│   ├── Dockerfile
│   └── run.sh
│
├── bitbake/
│
├── openembedded-core/
│
├── meta-project/
│   ├── conf/
│   ├── recipes-core/
│   ├── recipes-apps/
│   └── recipes-kernel/
│
├── meta-project-bsp/
│   ├── conf/
│   ├── recipes-bsp/
│   ├── recipes-kernel/
│   └── recipes-bootloader/
│
├── build/
│
├── downloads/
│
└── sstate-cache/
```

Layer responsibilities:

### meta-project

Application recipes and project-wide policies.

### meta-project-bsp

Board Support Package (BSP):

- U-Boot
- Linux kernel
- Device trees
- Firmware
- Platform configuration

# Step 11: Useful BitBake Commands

Show environment:

```bash
bitbake -e hello
```

List available tasks:

```bash
bitbake -c listtasks hello
```

Clean recipe:

```bash
bitbake -c clean hello
```

Clean sstate:

```bash
bitbake -c cleansstate hello
```

Run a single task:

```bash
bitbake -c compile hello
```

Force a rebuild:

```bash
bitbake -f -c compile hello
```

Generate dependency graphs:

```bash
bitbake -g project-image
```

# Step 12: Docker Cache Optimization

The `downloads/` and `sstate-cache/` directories were already created in Step 1 and are mounted into the container via `docker/run.sh`:

```text
downloads/
    Source archive cache

sstate-cache/
    Shared state cache
```

Benefits:
- Faster rebuilds
- Reduced network downloads
- Improved CI/CD performance

# Step 13: CI/CD Example

Build Docker image:

```bash
docker build \
    --build-arg USER_ID=$(id -u) \
    --build-arg GROUP_ID=$(id -g) \
    --build-arg USER_NAME=$(whoami) \
    -t project-yocto:1.0 \
    docker/
```

Run automated build:

```bash
docker run \
    --rm \
    -v $PWD:/workspace \
    project-yocto:1.0 \
    bash -c "
        source env.sh &&
        bitbake project-image
    "
```

# Final Directory Structure

```text
yocto-project/
│
├── docker/
│   ├── Dockerfile
│   └── run.sh
│
├── env.sh
│
├── bitbake/
│
├── openembedded-core/
│
├── meta-project/
│   ├── conf/
│   │   ├── layer.conf
│   │   ├── distro/
│   │   │   └── project.conf
│   │   └── machine/
│   │       └── qemux86-64.conf
│   │
│   ├── recipes-apps/
│   │   └── hello/
│   │       ├── hello.bb
│   │       └── files/
│   │           └── hello.c
│   │
│   ├── recipes-core/
│   │   └── images/
│   │       └── project-image.bb
│   │
│   └── recipes-kernel/
│
├── build/
│   └── conf/
│       ├── bblayers.conf
│       └── local.conf
│
├── downloads/
│
└── sstate-cache/
```

This setup provides a fully containerized OpenEmbedded/Yocto environment built 
from first principles using BitBake and OE-Core directly from GitHub, 
with manually managed layers, distro definitions, machine configurations, 
recipes, build configuration, and cache management.