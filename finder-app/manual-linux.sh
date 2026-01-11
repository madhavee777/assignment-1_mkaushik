#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.
# Hardened for M4 Mac/ARM64 and Pathing logic.

set -e
set -u

OUTDIR=$HOME/aeld-output
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.145
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-linux-gnu-

if [ $# -lt 1 ]; then
    echo "Using default directory ${OUTDIR} for output"
else
    OUTDIR=$1
fi

mkdir -p ${OUTDIR}

# --- KERNEL BUILD ---
cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi

if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} HOSTCFLAGS="-fcommon" defconfig
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} HOSTCFLAGS="-fcommon" olddefconfig
    make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} HOSTCFLAGS="-fcommon" all
fi
cp ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}/

# --- ROOTFS SETUP ---
if [ -d "${OUTDIR}/rootfs" ]; then
    sudo rm -rf ${OUTDIR}/rootfs
fi
mkdir -p ${OUTDIR}/rootfs
cd ${OUTDIR}/rootfs
mkdir -p bin dev etc home lib lib64 proc sbin sys tmp usr var usr/bin usr/lib usr/sbin var/log

# --- BUSYBOX ---
cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]; then
    # Use the stable GitHub mirror instead of git.busybox.net
    git clone https://github.com/mirror/busybox.git --depth 1 --single-branch --branch ${BUSYBOX_VERSION}
    cd busybox
    # If the tag format in the mirror is different, you might need to adjust:
    # git checkout ${BUSYBOX_VERSION} 
else
    cd busybox
fi

sed -i 's/CONFIG_TC=y/CONFIG_TC=n/' .config
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} CONFIG_PREFIX=${OUTDIR}/rootfs install

# --- LIBRARIES ---
echo "Finding and copying shared libraries..."

# Ask the compiler for its sysroot path (the "root" of its library world)
SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)

# Now copy the libraries using that dynamic path
# Note: On some systems they are in /lib, on others in /lib64
cp -L ${SYSROOT}/lib/ld-linux-aarch64.so.1 ${OUTDIR}/rootfs/lib/
cp -L ${SYSROOT}/lib/ld-linux-aarch64.so.1 ${OUTDIR}/rootfs/lib64/
cp -L ${SYSROOT}/lib64/libm.so.6 ${OUTDIR}/rootfs/lib/
cp -L ${SYSROOT}/lib64/libresolv.so.2 ${OUTDIR}/rootfs/lib/
cp -L ${SYSROOT}/lib64/libc.so.6 ${OUTDIR}/rootfs/lib/

# --- DEVICE NODES ---
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/null c 1 3
sudo mknod -m 600 ${OUTDIR}/rootfs/dev/console c 5 1

# --- BUILD WRITER ---
cd ${FINDER_APP_DIR}/finder-app
make clean
make CROSS_COMPILE=${CROSS_COMPILE}

# --- THE FINAL SANITIZED INSTALLATION ---
echo "Installing application and scripts to rootfs..."

# Since the script is now in finder-app/
# FINDER_APP_DIR=$(realpath $(dirname $0)) will be the finder-app folder.

# 1. Copy App files (Source is now current directory)
cp ${FINDER_APP_DIR}/writer         ${OUTDIR}/rootfs/home/
cp ${FINDER_APP_DIR}/writer         ${OUTDIR}/rootfs/home/writer.sh
cp ${FINDER_APP_DIR}/finder.sh      ${OUTDIR}/rootfs/home/
cp ${FINDER_APP_DIR}/finder-test.sh ${OUTDIR}/rootfs/home/
cp ${FINDER_APP_DIR}/autorun-qemu.sh ${OUTDIR}/rootfs/home/

# 2. Handle Configuration files (Source is one level up)
mkdir -p ${OUTDIR}/rootfs/home/conf
mkdir -p ${OUTDIR}/rootfs/conf
cp ${FINDER_APP_DIR}/../conf/username.txt   ${OUTDIR}/rootfs/home/conf/
cp ${FINDER_APP_DIR}/../conf/assignment.txt ${OUTDIR}/rootfs/home/conf/
cp ${FINDER_APP_DIR}/../conf/username.txt   ${OUTDIR}/rootfs/conf/
cp ${FINDER_APP_DIR}/../conf/assignment.txt ${OUTDIR}/rootfs/conf/

# The "Success" Fix: Sanitize shebangs and line endings inside the staging area
echo "Sanitizing scripts for BusyBox..."
cd ${OUTDIR}/rootfs/home
# We use sudo here to ensure permissions are preserved for the root owner
sudo sed -i 's/#!.*bash/#! \/bin\/sh/' finder.sh finder-test.sh autorun-qemu.sh
sudo sed -i 's/\r$//' finder.sh finder-test.sh autorun-qemu.sh
sudo chmod +x writer writer.sh finder.sh finder-test.sh autorun-qemu.sh

# --- FINAL PACKAGE ---
echo "Packaging rootfs into initramfs..."
cd ${OUTDIR}/rootfs
sudo chown -R root:root *
# Create the cpio archive from the sanitized rootfs
find . | cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio
cd ${OUTDIR}
gzip -f initramfs.cpio

echo "SUCCESS! Created ${OUTDIR}/initramfs.cpio.gz"


