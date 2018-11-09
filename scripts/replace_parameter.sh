#!/bin/bash

usage() {

    echo './replace_parameter.sh <REGISTER> <LINK> <VALUE>'
	echo './replace_parameter.sh -f <FILENAME> <REGISTER> <LINK>'
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
}

ISFILE=0;
OPTIND=1
while getopts "f:h" opts
do
    case $opts in
        f)
            FILENAME=$OPTARG;;
        h)
            usage
            exit;;
        \?)
            usage
            exit;;
        [?])
            usage
            exit;;
    esac
done
unset OPTIND

if [ -z ${FILENAME} ]; then
    if [ -z ${3+x} ]
    then
	    usage
        echo ""
        echo "        The -f flag was not provided, so the first usage example above should be followed."
        exit
    fi
    REGISTER=$1
    VALUE=$3
    LINK=$2
    sed -i "s|^${REGISTER}.*|${REGISTER}   ${VALUE}|g" /mnt/persistent/gemdaq/vfat3/config_OH${LINK}_VFAT*_cal.txt
else
    if [ -z ${4+x} ]
    then
	    usage
        echo ""
        echo "        The -f flag was provided, so the second usage example above should be followed."
        exit
    fi
    REGISTER=$2
    LINK=$3
    awk '{system("sed -i \"s|^'$REGISTER'.*|'$REGISTER'   "$2"|g\" /mnt/persistent/gemdaq/vfat3/config_OH'$LINK'_VFAT"$1"_cal.txt")}' $FILENAME
fi
