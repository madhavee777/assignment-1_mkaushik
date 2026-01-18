#!/bin/sh
# IF Number of args is 2
if [ $# -eq 2 ]; then

	#$1 refers to the first argument
        if [ -d $1 ]; then
                x=$(ls $1 -r | wc -l)
                y=$(grep -r $2 $1 | wc -l)
                echo "The number of files are $x and the number of matching lines are $y"
                # forgetting exit 0 would lead to error in the caller script
                exit 0

	else
		echo "The given dir does not exists !!"
	fi
        exit 1

else 

	echo "failed: Few or more than 2 args passed !!"
        exit 1

fi 
#!/bin/bash
# IF Number of args is 2
if [ $# -eq 2 ]; then

	#$1 refers to the first argument
        if [ -d $1 ]; then
                x=$(ls $1 -r | wc -l)
                y=$(grep -r $2 $1 | wc -l)
                echo "The number of files are $x and the number of matching lines are $y"
                # forgetting exit 0 would lead to error in the caller script
                exit 0

	else
		echo "The given dir does not exists !!"
	fi
        exit 1

else 

	echo "failed: Few or more than 2 args passed !!"
        exit 1

fi 
