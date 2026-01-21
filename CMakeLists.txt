cmake_minimum_required(VERSION 3.10)
project(aesd-assignments)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -pthread -g -Wall -Wno-error")

# 1. Student Code (Implementation)
#    Includes System Calls (Assgn 3) and Threading (Assgn 4/5)
set(TESTED_SOURCE
    ../examples/systemcalls/systemcalls.c
    ../examples/threading/threading.c
)

# 2. Test Code (The Grader's Code)
#    Includes tests for both previous and current assignments
set(AUTOTEST_SOURCES
    test/assignment3/Test_systemcalls.c
    test/assignment4/Test_threading.c
)

# 3. Add the testing framework
add_subdirectory(assignment-autotest)


