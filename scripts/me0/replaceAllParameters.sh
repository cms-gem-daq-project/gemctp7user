#!/bin/sh

usage() {
    echo 'replaceAllParameters <PATH> <LINK>'
    echo ''
    echo '  PATH - physical filepath where NominalValues-*.txt files produced by anaDACScan.py are found. 
                   Note the string "NominalValues" must be in the filenames'
    echo ''
    echo '  LINK - OH Number to apply parameters too'
    echo ''
    echo '  Example:'
    echo ''
    echo '      replaceAllParameters /mnt/persistent/gemuser 3'
    echo''
    kill -INT $$
}

# Check inputs
if [ -z ${2+x} ]
then
    usage
fi

PATH=$1
LINK=$2

if [ -z ${LINK} ]
then
    echo 'No link supplied'
    usage
fi

for file in "$PATH/NominalValues"*
do
    echo "$file"
    for substr in "$(echo $file | awk -F _ '{print $1}' )"
    do
        echo $substr
    done
done
