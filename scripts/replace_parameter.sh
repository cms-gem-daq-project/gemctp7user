#!/bin/bash

usage() {

	echo './replace_parameter.sh [-f] <REGISTER> <LINK> <VALUE/FILENAME>'
	echo ''
	echo '	REGISTER - register to be updated dropping the "CFG_" substring'
	echo ''
	echo '	VALUE/FILENAME - value in decimal to be assigned to REGISTER or, if the -f option is used, filename containing a list of vfat number/ value pairs'
	echo ''
	echo '	Examples:'
	echo ''
	echo '		./replace_parameter.sh PULSE_STRETCH 4 1'
	echo '		./replace_parameter.sh -f PULSE_STRETCH 4 /path/to/NominalDacValues.txt'
	echo ''    

	kill -INT $$; 
}

ISFILE=0;
OPTIND=1
while getopts "fwhd" opts
do
    case $opts in
        f)
            ISFILE=1;;
        h)
            usage;;
        \?)
            usage;;
        [?])
            usage;;
    esac
done
unset OPTIND

if (($ISFILE == 1)); then
    if [ -z ${4+x} ]
    then
	    usage
    fi
    REGISTER=$2
    LINK=$3
    FILENAME=$4
    awk '{system("sed -i \"s|^'$REGISTER'.*|'$REGISTER'   "$2"|g\" /mnt/persistent/gemdaq/vfat3/config_OH'$LINK'_VFAT"$1"_cal.txt")}' $FILENAME
else
    if [ -z ${3+x} ]
    then
	    usage
    fi
    REGISTER=$1
    LINK=$2
    VALUE=$3
    sed -i "s|^${REGISTER}.*|${REGISTER}   ${VALUE}|g" /mnt/persistent/gemdaq/vfat3/config_OH${LINK}_VFAT*_cal.txt
fi
