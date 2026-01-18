#!/bin/bash
# Script to build the project
set -e

# 1. Enter the buildroot directory
cd buildroot

# 2. Fix the Overlay Path: Create a symlink so Buildroot can find the overlay
#    The config expects 'base_external/rootfs_overlay' to exist locally.
if [ ! -d "base_external" ]; then
    echo "Creating symlink for base_external..."
    ln -s ../base_external base_external
fi

# 3. Configure Buildroot
#    We use realpath for the external tree to ensure variables are set correctly
echo "Configuring Buildroot..."
make BR2_EXTERNAL=$(realpath ../base_external) aesd_qemu_defconfig

# 4. Build the Project
echo "Building Project..."
make



