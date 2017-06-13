#!/bin/sh

CTP7s=( eagle34 )

for i in ${CTP7s[@]}; do

                printf "\n=====================================================\n"
                printf "RX Opto Power Measurement on %s\n" ${i}

                ssh root@${i} "rawi2c /dev/i2c-2 w 0x54 127 1 > /dev/null; \
                                rawi2c /dev/i2c-3 w 0x54 127 1 > /dev/null; \
                                rawi2c /dev/i2c-4 w 0x54 127 1 > /dev/null; "

                printf "\n---  CXP0   ---\n"
                ssh root@${i} "rawi2c /dev/i2c-2 r 0x54 206 24" > tmp.txt
                ./parse_i2c_opto_power.py `cat tmp.txt`

                printf "\n---  CXP1   ---\n"
                ssh root@${i} "rawi2c /dev/i2c-3 r 0x54 206 24" > tmp.txt
                ./parse_i2c_opto_power.py `cat tmp.txt`

                printf "\n---  CXP2   ---\n"
                ssh root@${i} "rawi2c /dev/i2c-4 r 0x54 206 24" > tmp.txt
                ./parse_i2c_opto_power.py `cat tmp.txt`
done

