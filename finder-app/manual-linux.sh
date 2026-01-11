#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.
# Updated for M4 Mac and GitHub Autograder compatibility.

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
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all
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
    git clone https://github.com/mirror/busybox.git --depth 1 --single-branch --branch ${BUSYBOX_VERSION}
fi
cd busybox
make distclean
make defconfig
sed -i 's/CONFIG_TC=y/CONFIG_TC=n/' .config
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} CONFIG_PREFIX=${OUTDIR}/rootfs install

# --- LIBRARIES ---
echo "Finding and copying shared libraries..."
SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)
if [ -z "$SYSROOT" ]; then
    SYSROOT="/usr/aarch64-linux-gnu"
fi

# Create all necessary library directories
mkdir -p ${OUTDIR}/rootfs/lib
mkdir -p ${OUTDIR}/rootfs/lib64
mkdir -p ${OUTDIR}/rootfs/usr/lib
mkdir -p ${OUTDIR}/rootfs/lib/aarch64-linux-gnu

find_and_copy() {
    local lib=$1
    local path=$(find $SYSROOT -name "$lib" -print -quit)
    if [ -z "$path" ]; then
        path=$(find /lib/aarch64-linux-gnu /usr/lib/aarch64-linux-gnu -name "$lib" -print -quit 2>/dev/null || true)
    fi

    if [ ! -z "$path" ]; then
        echo "Found $lib at $path"
        # Copy to all standard locations to be absolutely sure
        cp -v -P "$path"* "${OUTDIR}/rootfs/lib/"
        cp -v -P "$path"* "${OUTDIR}/rootfs/lib64/"
        cp -v -P "$path"* "${OUTDIR}/rootfs/usr/lib/"
    else
        echo "Error: Could not find $lib"
        exit 1
    fi
}

# Copy the libraries
find_and_copy "ld-linux-aarch64.so.1"
find_and_copy "libm.so.6"
find_and_copy "libresolv.so.2"
find_and_copy "libc.so.6"

# MANDATORY SYMLINK: Many binaries look for the loader specifically here
cd ${OUTDIR}/rootfs/lib
ln -sf ld-linux-aarch64.so.1 ld-2.31.so || true # Try to link to versioned name if possible

# --- DEVICE NODES ---
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/null c 1 3
sudo mknod -m 600 ${OUTDIR}/rootfs/dev/console c 5 1

# --- INSTALLATION ---
cd ${FINDER_APP_DIR}
make clean
make CROSS_COMPILE=${CROSS_COMPILE}

cp writer ${OUTDIR}/rootfs/home/
cp writer ${OUTDIR}/rootfs/home/writer.sh
cp finder.sh finder-test.sh autorun-qemu.sh ${OUTDIR}/rootfs/home/

# Setup conf files
mkdir -p ${OUTDIR}/rootfs/home/conf
mkdir -p ${OUTDIR}/rootfs/conf
cp ../conf/assignment.txt ../conf/username.txt ${OUTDIR}/rootfs/home/conf/
cp ../conf/assignment.txt ../conf/username.txt ${OUTDIR}/rootfs/conf/

# Fix shebangs for BusyBox (no bash in busybox)
sed -i 's/#!.*bash/#! \/bin\/sh/' ${OUTDIR}/rootfs/home/*.sh

# --- PACKAGE ---
cd ${OUTDIR}/rootfs
sudo chown -R root:root *
find . | cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio
cd ${OUTDIR}
gzip -f initramfs.cpio



