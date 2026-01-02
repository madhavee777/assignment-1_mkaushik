#!/bin/bash
# Nested if statements
if [ $# -eq 2 ]
    then
    writefile="$1"
    writestr="$2"
    if [ -d writefile ]
        then
        # file does exist : write to it
        echo "$writestr" > "$writefile"
    else
        # file does not exit : make new and write to it
        mkdir -p "$(dirname $writefile)" && touch "$writefile"
        echo "$writestr" > "$writefile"
    fi
else
    echo "More or less args are passed"
    exit 1
fi
