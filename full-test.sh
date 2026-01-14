#!/bin/bash
# Stop on errors
set -e

echo "------------------------------------------------"
echo "  Starting Assignment 4 Full Test (Buildroot)"
echo "------------------------------------------------"

# 1. Enter the directory
cd buildroot

# 2. Configure Buildroot (The Missing Step)
#    This tells Buildroot to use your settings from 'base_external'
#    and creates the .config file.
echo "Loading configuration..."
make BR2_EXTERNAL=../base_external aesd_qemu_defconfig

# 3. Build the Project
echo "Building... (This will take 30-45 minutes)"
make

echo "------------------------------------------------"
echo "  Buildroot Build Complete!"
echo "------------------------------------------------"



