#!/bin/bash
# Stop on errors
set -e

# FIX: Tell build tools it is okay to run as root
export FORCE_UNSAFE_CONFIGURE=1

echo "------------------------------------------------"
echo "  Starting Assignment 4 Full Test (Buildroot)"
echo "------------------------------------------------"

# 1. Enter the directory
cd buildroot

# FIX: Create a symlink so Buildroot finds the external folder locally
#      It maps 'buildroot/base_external' -> '../base_external'
if [ ! -d "base_external" ]; then
    ln -s ../base_external base_external
fi

# 2. Configure Buildroot
echo "Loading configuration..."
make BR2_EXTERNAL=../base_external aesd_qemu_defconfig

# 3. Build the Project
echo "Building... (This will take 30-45 minutes)"
make

echo "------------------------------------------------"
echo "  Buildroot Build Complete!"
echo "------------------------------------------------"



