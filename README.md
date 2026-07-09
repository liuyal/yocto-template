# Quick Guide: Building a Yocto Image

This guide covers the basic steps to build a Yocto Linux image from scratch.

---

## 1. Install Host Dependencies

On Ubuntu:

```bash
sudo apt update
sudo apt install -y \
    gawk wget git diffstat unzip texinfo gcc build-essential \
    chrpath socat cpio python3 python3-pip python3-pexpect \
    xz-utils debianutils iputils-ping python3-git python3-jinja2 \
    libegl1 libsdl1.2-dev pylint xterm lz4
```

Install ZsaclerRootCA
```
sudo cp ZscalerRootCA.crt /usr/local/share/ca-certificates/ZscalerRootCA.crt
sudo update-ca-certificates
```

---

## 2. Download Yocto (Poky)

Clone the Yocto Project reference distribution:

```bash
git clone https://git.yoctoproject.org/poky
cd poky
```

Checkout a specific release if required:

```bash
git checkout scarthgap
```

---

## 3. Initialize the Build Environment

```bash
source oe-init-build-env
```

This creates a `build/` directory and enters it.

---

## 4. Configure the Build

Edit:

```bash
build/conf/local.conf
```

Example:

```conf
MACHINE = "qemux86-64"
```

---

## 5. Add Additional Layers (Optional)

List current layers:

```bash
bitbake-layers show-layers
```

Add a layer:

```bash
bitbake-layers add-layer ../meta-openembedded/meta-networking
```

---

## 6. Build an Image

Minimal image:
```bash
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
```

```bash
bitbake core-image-minimal
```

Full command-line image:

```bash
bitbake core-image-full-cmdline
```

GUI image:

```bash
bitbake core-image-sato
```

---

## 7. Locate Build Artifacts

```bash
tmp/deploy/images/<machine>/
```

Example:

```bash
tmp/deploy/images/qemux86-64/
```

---

## 8. Run the Image in QEMU

```bash
runqemu qemux86-64
```

---

## 9. Clean a Build

Clean recipe:

```bash
bitbake -c clean <recipe>
```

Force rebuild:

```bash
bitbake -c cleansstate <recipe>
```

---

## 10. Common Commands

```bash
bitbake-layers show-recipes
bitbake-layers show-layers
bitbake -e <recipe>
```

---

## Troubleshooting

Check disk usage:

```bash
du -sh tmp/
du -sh sstate-cache/
```

Remove temporary files:

```bash
rm -rf tmp
```

---

## Typical Daily Workflow

```bash
cd poky
source oe-init-build-env

bitbake-layers show-layers
bitbake core-image-minimal
runqemu qemux86-64
```
