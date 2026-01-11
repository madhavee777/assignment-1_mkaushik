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
# Since script is in finder-app/, FINDER_APP_DIR is the finder-app folder
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
    echo "Cloning Linux Kernel..."
    git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi

if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out kernel version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    echo "Building Kernel..."
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all
fi

echo "Adding Kernel Image to ${OUTDIR}"
cp ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}/

# --- ROOTFS SETUP ---
echo "Creating the staging directory for the root filesystem"
if [ -d "${OUTDIR}/rootfs" ]; then
    sudo rm -rf ${OUTDIR}/rootfs
fi
mkdir -p ${OUTDIR}/rootfs
cd ${OUTDIR}/rootfs
mkdir -p bin dev etc home lib lib64 proc sbin sys tmp usr var usr/bin usr/lib usr/sbin var/log

# --- BUSYBOX ---
cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]; then
    # Using GitHub mirror for better reliability on Autograder
    git clone https://github.com/mirror/busybox.git --depth 1 --single-branch --branch ${BUSYBOX_VERSION}
    cd busybox
else
    cd busybox
fi

# FIX: Generate defconfig FIRST, then run sed
make distclean
make defconfig
sed -i 's/CONFIG_TC=y/CONFIG_TC=n/' .config

make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} CONFIG_PREFIX=${OUTDIR}/rootfs install

# --- LIBRARIES ---
echo "Finding and copying shared libraries..."

# Try to find sysroot, but if it's empty, use the standard Ubuntu cross-tool path
SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)
if [ -z "$SYSROOT" ]; then
    SYSROOT="/usr/aarch64-linux-gnu"
fi

echo "Using SYSROOT: $SYSROOT"

# Create lib64 as it is mandatory for the loader
mkdir -p ${OUTDIR}/rootfs/lib
mkdir -p ${OUTDIR}/rootfs/lib64

# Function to search multiple paths for the libraries
find_and_copy() {
    local lib=$1
    # Search in SYSROOT and standard toolchain paths
    local path=$(find $SYSROOT -name "$lib" -print -quit)
    
    if [ -z "$path" ]; then
        # Fallback for Ubuntu/Debian native layouts
        path=$(find /lib/aarch64-linux-gnu /usr/lib/aarch64-linux-gnu -name "$lib" -print -quit 2>/dev/null || true)
    fi

    if [ ! -z "$path" ]; then
        echo "Found $lib at $path"
        cp -L "$path" "${OUTDIR}/rootfs/lib/"
        # If it's the loader, also put it in lib64
        if [ "$lib" == "ld-linux-aarch64.so.1" ]; then
            cp -L "$path" "${OUTDIR}/rootfs/lib64/"
        fi
    else
        echo "Error: Could not find $lib"
        exit 1
    fi
}

find_and_copy "ld-linux-aarch64.so.1"
find_and_copy "libm.so.6"
find_and_copy "libresolv.so.2"
find_and_copy "libc.so.6"

# --- DEVICE NODES ---
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/null c 1 3
sudo mknod -m 600 ${OUTDIR}/rootfs/dev/console c 5 1

# --- BUILD WRITER ---
cd ${FINDER_APP_DIR}
make clean
make CROSS_COMPILE=${CROSS_COMPILE}

# --- INSTALLATION ---
echo "Installing application and scripts to rootfs..."
cp ${FINDER_APP_DIR}/writer ${OUTDIR}/rootfs/home/
cp ${FINDER_APP_DIR}/writer ${OUTDIR}/rootfs/home/writer.sh
cp ${FINDER_APP_DIR}/finder.sh ${OUTDIR}/rootfs/home/
cp ${FINDER_APP_DIR}/finder-test.sh ${OUTDIR}/rootfs/home/
cp ${FINDER_APP_DIR}/autorun-qemu.sh ${OUTDIR}/rootfs/home/

# Copy conf folder from the repository root (one level up from finder-app)
mkdir -p ${OUTDIR}/rootfs/home/conf
mkdir -p ${OUTDIR}/rootfs/conf
cp ${FINDER_APP_DIR}/../conf/assignment.txt ${OUTDIR}/rootfs/home/conf/
cp ${FINDER_APP_DIR}/../conf/username.txt ${OUTDIR}/rootfs/home/conf/
cp ${FINDER_APP_DIR}/../conf/assignment.txt ${OUTDIR}/rootfs/conf/
cp ${FINDER_APP_DIR}/../conf/username.txt ${OUTDIR}/rootfs/conf/

# Sanitize for BusyBox
sed -i 's/#!.*bash/#! \/bin\/sh/' ${OUTDIR}/rootfs/home/*.sh

# --- PACKAGE ---
cd ${OUTDIR}/rootfs
sudo chown -R root:root *
find . | cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio
cd ${OUTDIR}
gzip -f initramfs.cpio


