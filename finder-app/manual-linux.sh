#!/bin/bash
# Final Robust manual-linux.sh for Assignment 3 Part 2
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

# --- LIBRARIES (THE ROBUST FIX) ---
echo "Finding and copying shared libraries..."
# Get the sysroot from the compiler
SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)

# If sysroot is empty, use the common cross-lib directory
if [ -z "$SYSROOT" ]; then
    SYSROOT="/usr/aarch64-linux-gnu"
fi

# List of potential paths where libraries might live on Ubuntu/Debian
SEARCH_PATHS="$SYSROOT/lib $SYSROOT/lib64 /usr/aarch64-linux-gnu/lib /usr/lib/aarch64-linux-gnu"

for lib in ld-linux-aarch64.so.1 libm.so.6 libresolv.so.2 libc.so.6; do
    echo "Searching for $lib..."
    LIB_PATH=""
    for search_path in $SEARCH_PATHS; do
        if [ -f "$search_path/$lib" ]; then
            LIB_PATH="$search_path/$lib"
            break
        fi
    done

    if [ -n "$LIB_PATH" ]; then
        echo "Found $lib at $LIB_PATH"
        cp -aL "$LIB_PATH" "${OUTDIR}/rootfs/lib/"
        cp -aL "$LIB_PATH" "${OUTDIR}/rootfs/lib64/"
    else
        echo "ERROR: Could not find $lib in any of the search paths."
        exit 1
    fi
done

# --- DEVICE NODES ---
cd ${OUTDIR}/rootfs
sudo mknod -m 666 dev/null c 1 3
sudo mknod -m 600 dev/console c 5 1

# --- INSTALLATION ---
cd ${FINDER_APP_DIR}
make clean
make CROSS_COMPILE=${CROSS_COMPILE}

cp writer finder.sh finder-test.sh autorun-qemu.sh ${OUTDIR}/rootfs/home/
cp writer ${OUTDIR}/rootfs/home/writer.sh

mkdir -p ${OUTDIR}/rootfs/home/conf
mkdir -p ${OUTDIR}/rootfs/conf
cp ../conf/*.txt ${OUTDIR}/rootfs/home/conf/
cp ../conf/*.txt ${OUTDIR}/rootfs/conf/

sed -i 's/#!.*bash/#! \/bin\/sh/' ${OUTDIR}/rootfs/home/*.sh

# --- PACKAGE ---
cd ${OUTDIR}/rootfs
sudo chown -R root:root *
find . | sudo cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio
cd ${OUTDIR}
gzip -f initramfs.cpio


