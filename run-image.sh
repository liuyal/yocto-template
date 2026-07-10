#!/bin/bash
# Wrapper around runqemu that works around the bitbake -e subprocess capture issue.
# Usage: ./run-image.sh [nographic] [slirp] [kvm]

set -e

DEPLOY_DIR=/workspace/build/tmp/deploy/images/qemux86-64
KERNEL=$DEPLOY_DIR/bzImage
ROOTFS=$DEPLOY_DIR/project-image-qemux86-64.ext4
QEMUBOOT_CONF=$DEPLOY_DIR/project-image-qemux86-64.qemuboot.conf

# Parse optional flags
NOGRAPHIC=""
KVM=""
EXTRA_APPEND=""
for arg in "$@"; do
    case $arg in
        nographic) NOGRAPHIC="-nographic" ;;
        kvm)       KVM="-enable-kvm" ;;
    esac
done

if [ -z "$NOGRAPHIC" ]; then
    DISPLAY_OPT="-display gtk"
else
    DISPLAY_OPT="-nographic"
fi

echo "Booting: $ROOTFS"
echo "Kernel:  $KERNEL"
echo "Press Ctrl+A then X to exit QEMU"
echo ""

exec qemu-system-x86_64 \
    -kernel "$KERNEL" \
    -cpu IvyBridge \
    -machine q35,i8042=off \
    -m 256 \
    -smp 4 \
    -device virtio-scsi-pci,id=scsi0 \
    -device scsi-hd,drive=disk0 \
    -drive id=disk0,file="$ROOTFS",if=none,format=raw \
    -netdev user,id=net0 \
    -device virtio-net-pci,netdev=net0,mac=52:54:00:12:34:02 \
    -object rng-random,filename=/dev/urandom,id=rng0 \
    -device virtio-rng-pci,rng=rng0 \
    -usb -device usb-tablet \
    -usb -device usb-kbd \
    -serial mon:stdio \
    -serial null \
    $DISPLAY_OPT \
    $KVM \
    -append "root=/dev/sda rw console=ttyS0,115200 oprofile.timer=1 tsc=reliable no_timer_check rcupdate.rcu_expedited=1 swiotlb=0"

