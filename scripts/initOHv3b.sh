#!/bin/sh

usage() {
    echo 'Usage: ./initOHv3b.sh <OH Mask> <GBT0 File> <GBT1 File> <GBT2 File> <Bit File>'
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
    echo '          Bit File -  Firmaware file (*.bit) to program all FPGAs with'
    echo ''
    echo '  Example:'
    echo '      ./initOHv3b.sh 0x1 ~/gbt/GBTX_OHv3b_GBT_0__2018-02-25_FINAL.txt ~/gbt/GBTX_OHv3b_GBT_1__2018-02-25_FINAL.txt ~/gbt/GBTX_OHv3b_GBT_2__2018-02-25_FINAL.txt ~/oh_fw/OH-20180306-3.1.0.B.bit'
    echo ''

    kill -INT $$;
} 

# Check inputs
if [ -z ${5+x} ] 
then
    usage
fi

OHMASK=$1
FILE_GBT0=$2
FILE_GBT1=$3
FILE_GBT2=$4
FILE_FW=$5

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

if [ ! -f $FILE_FW ]; then
    echo "Input file: ${FILE_FW} not found"
    echo "Please cross-check, exiting"
    kill -INT $$;
fi

# Program GBT's
cd ~/apps/reg_interface
#for link in {0..11..1}
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

# Issue an sca reset
sca.py $OHMASK r

# Program the FPGA's
sca.py $OHMASK program-fpga bit $FILE_FW

if [[ $FILE_FW =~ (([0-9a-fA-F]+)\.){3}([Bb]\.) ]]; then
    # OHv3b
    reg_interface.py -e write "GEM_AMC.GEM_SYSTEM.VFAT3.USE_OH_V3B_MAPPING 1"
else
    # OHv3a
    # Necessary for FW versions pre-dating v3.1.0.B
    #for link in 0 1 2 3 4 5 6 7 8 9 10 11
    #do
    #    if [ $(( ($OHMASK>>$link) & 0x1 )) -eq 1 ]; then
    #        echo "Setting OHv3b SBIT timing for link $link"
    #        configure_oh_for_gebv3b_short.py -g$link
    #        configure_oh_for_ohv3b.py -g$link
    #    else
    #        echo "nothing to be done for link $link"
    #    fi
    #done

    reg_interface --execute="write GEM_AMC.GEM_SYSTEM.VFAT3.USE_OH_V3B_MAPPING 0"
fi

# Link reset
reg_interface.py -e write "GEM_AMC.GEM_SYSTEM.CTRL.LINK_RESET 1"

# TU invert (forget for which FW versions this is required...)
#reg_interface.py -e write "GEM_AMC.OH.OH0.FPGA.TRIG.CTRL.VFAT17_TU_INVERT 0x6"

# Return to original directory
cd $DIR_ORIG

echo "Completed, Your OH's are ready to use"
