#!/bin/sh


if [ -z $1 ]; then
	echo "Please give an IPBus address to test"
	exit
fi

#addr=$((0x64000000 + ($1 << 2)))
addr=$1  # e.g. 0x6502c000 is VFAT.MASK

OH_ADDR=$addr
ITERATION=0
OH=0
ERRORS=0
TIME_START=`date +%s`
HEX_NUMBER_RE=^0[xX][0-9a-fA-F]+$

while [ $ITERATION -lt 1000 ]; do
	VALUE=`awk -F - '{print(("0x"$1) % 0xffff)}' /proc/sys/kernel/random/uuid`
	#echo "writing $VALUE"
  while [ $OH -lt 1 ]; do
        OH_ADDR=$(($addr + $OH * 0x40000))
	mpoke $OH_ADDR $VALUE
        #echo "OH $OH: writing $VALUE to $OH_ADDR"
	READBACK=`mpeek $OH_ADDR`
        #echo "read back $READBACK"
	if ! echo $READBACK | egrep -q $HEX_NUMBER_RE; then
		echo "ERROR OH $OH: readback is not a number: $READBACK"
		let ERRORS=ERRORS+1
	elif [ $VALUE -ne $(( $READBACK )) ]; then
		echo "ERROR OH $OH: wrote $VALUE, got $READBACK, which is $(( $READBACK ))"
		let ERRORS=ERRORS+1
#		echo "exiting on first error (comment this line to not exits and count errors instead)"
#		exit
	fi
	let OH=OH+1
  done
	let ITERATION=ITERATION+1
	let OH=0
	echo "Iteration $ITERATION"
done

TIME_END=`date +%s`

echo "Total errors: $ERRORS"
echo "Total time spent: $(( $TIME_END - $TIME_START ))"
