#!/bin/bash

usage() {
	echo './replace_parameter.sh <REGISTER> <VALUE> <LINK>'
	echo ''
	echo '	REGISTER - register to be updated dropping the "CFG_" substring'
	echo ''
	echo '	VALUE - value in decimal to be assigned to REGISTER'
	echo ''
	echo '	Example:'
	echo ''
	echo '		./replace_parameter.sh PULSE_STRETCH 4 1'
	echo ''

	kill -INT $$; 
}

if [ -z ${3+x} ]
then
	usage
fi

REGISTER=$1
VALUE=$2
LINK=$3

sed -i "s|.*${REGISTER}.*|${REGISTER}	${VALUE}|g" /mnt/persistent/gemdaq/vfat3/config_OH${LINK}_VFAT*_cal.txt
