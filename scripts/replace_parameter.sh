#!/bin/bash

usage() {

    echo './replace_parameter.sh [-f <FILENAME>] <REGISTER> <LINK> <VALUE>'
    echo ''
    echo '	REGISTER - register to be updated dropping the "CFG_" substring'
    echo ''
    echo '	VALUE - value in decimal to be assigned to REGISTER'
    echo ''
    echo '	FILENAME - name of a file containing a list of vfat number/value pairs'
    echo ''
    echo '	Examples:'
    echo ''
    echo '		./replace_parameter.sh PULSE_STRETCH 1 4'
    echo '		./replace_parameter.sh -f /path/to/NominalDacValues.txt PULSE_STRETCH 1'
    kill -INT $$
}

ISFILE=0;
OPTIND=1
while getopts "f:h" opts
do
    case $opts in
        f)
            FILENAME=$OPTARG;;
        h)
            usage;;
        \?)
            usage;;
        [?])
            usage;;
    esac
done
shift $((OPTIND-1))
unset OPTIND

REGISTER=$1
LINK=$2
VALUE=$3

if [ -z ${LINK} ]
then
    echo 'No link supplied'
    usage
fi

if [ -z ${FILENAME} ]
then
    if [ -z ${VALUE} ]
    then
        echo 'No value supplied'
        usage
    else
        sed -i "s|^${REGISTER}.*|${REGISTER}   ${VALUE}|g" /mnt/persistent/gemdaq/vfat3/config_OH${LINK}_VFAT*_cal.txt
    fi
else
    if [ -f ${FILENAME} ]
    then
        awk '{system("sed -i \"s|^'$REGISTER'.*|'$REGISTER'   "$2"|g\" /mnt/persistent/gemdaq/vfat3/config_OH'$LINK'_VFAT"$1"_cal.txt")}' $FILENAME
    else
        echo "File ${FILENAME} not found"
    fi
fi
