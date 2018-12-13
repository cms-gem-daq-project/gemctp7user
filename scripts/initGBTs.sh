#!/bin/sh

usage() {
    echo 'Usage: ./initGBTs.sh <OH Mask> <GBT0 File> <GBT1 File> <GBT2 File>'
    echo ''
    echo '          OH Mask -   Mask specifying which links to program, e.g. 0x3ff is all 12,'
    echo '                      while 0x2 is just link 1'
    echo ''
    echo '          GBT0 File - File specifying GBT0 configuration'
    echo ''
    echo '          GBT1 File - File specifying GBT1 configuration'
    echo ''
    echo '          GBT2 File - File specifying GBT2 configuration'
    echo ''
    echo '  Example:'
    echo '      initGBTs.sh 0xffc ~/gbt/GBTX_OHv3b_GBT_0__2018-02-25_FINAL.txt ~/gbt/GBTX_OHv3b_GBT_1__2018-02-25_FINAL.txt ~/gbt/GBTX_OHv3b_GBT_2__2018-02-25_FINAL.txt'
    echo ''

    kill -INT $$;
} 

# Check inputs
if [ -z ${4+x} ] 
then
    usage
fi

OHMASK=$1
FILE_GBT0=$2
FILE_GBT1=$3
FILE_GBT2=$4

DIR_ORIG=$PWD

# Check if input files exist
if [ ! -f $FILE_GBT0 ]; then
    echo "Input file: ${FILE_GBT0} not found"
    echo "Please cross-check, exiting"
    kill -INT $$;
fi


if [ ! -f $FILE_GBT1 ]; then
    echo "Input file: ${FILE_GBT1} not found"
    echo "Please cross-check, exiting"
    kill -INT $$;
fi


if [ ! -f $FILE_GBT2 ]; then
    echo "Input file: ${FILE_GBT2} not found"
    echo "Please cross-check, exiting"
    kill -INT $$;
fi

# Program GBT's
for link in 0 1 2 3 4 5 6 7 8 9 10 11
do
    if [ $(( ($OHMASK>>$link) & 0x1 )) -eq 1 ]; then
        echo "Programming link $link"
        gbt.py $link 0 config $FILE_GBT0
        gbt.py $link 1 config $FILE_GBT1
        gbt.py $link 2 config $FILE_GBT2
    else
        echo "nothing to be done for link $link"
    fi
done

# Return to original directory
cd $DIR_ORIG
