#!/bin/bash
# Stop the script if any command fails
set -e

echo "------------------------------------------------"
echo "  Starting Assignment 4 Full Test (Buildroot)"
echo "------------------------------------------------"

# 1. Enter the buildroot directory
cd buildroot

# 2. Build the Project
#    This commands builds the Toolchain, Kernel, and RootFS.
#    It will take 30-45 minutes on the server.
echo "Running make..."
make

echo "------------------------------------------------"
echo "  Buildroot Build Complete!"
echo "------------------------------------------------"



