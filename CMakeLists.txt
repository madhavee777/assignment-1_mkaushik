cmake_minimum_required(VERSION 3.10)
project(aesd-assignments)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -pthread -g -Wall -Wno-error")

# 1. Student Code (Your implementation)
#    Use "../" because the build happens inside the submodule, 
#    so it needs to step up to the root to find your examples folder.
set(TESTED_SOURCE
    ../examples/threading/threading.c
    ../examples/systemcalls/systemcalls.c
)

# 2. Test Code (The Grader's Code)
#    Do NOT include "assignment-autotest/" in the path.
#    The build is already running inside that folder.
set(AUTOTEST_SOURCES
    test/assignment4/Test_threading.c
    test/assignment3/Test_systemcalls.c
)

# 3. Add the testing framework
add_subdirectory(assignment-autotest)



