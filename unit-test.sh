#!/bin/bash
# Run unit tests for the assignment

# Automate these steps from the readme:
# Create a build subdirectory, change into it, run
# cmake .. && make && run the assignment-autotest application
mkdir -p build
cd build
cmake ..
make clean
make
# 4. Run the resulting test executable
#    CMake puts the file inside the submodule folder
if [ -f "assignment-autotest/assignment-autotest" ]; then
    ./assignment-autotest/assignment-autotest
else
    echo "Test executable not found in assignment-autotest/ subdirectory."
    exit 1
fi




