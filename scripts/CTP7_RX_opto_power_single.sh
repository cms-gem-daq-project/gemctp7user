#!/bin/sh

CTP7_DUT=$1

printf "\n=====================================================\n"
printf "RX Opto Power Measurement on %s\n" $CTP7_DUT

# Enable the upper page to read the opto power from CXPs
# No need for something similar for the MiniPods
ssh $CTP7_DUT "rawi2c /dev/i2c-2 w 0x54 127 1 > /dev/null; \
	    rawi2c /dev/i2c-3 w 0x54 127 1 > /dev/null; \
	    rawi2c /dev/i2c-4 w 0x54 127 1 > /dev/null; "

	    printf "\n---   MP0   ---\n"
	    ./parse_i2c_opto_power.py `ssh $CTP7_DUT "rawi2c /dev/i2c-1 r 0x30 64 24"`

	    printf "\n---   MP1   ---\n"
	    ./parse_i2c_opto_power.py `ssh $CTP7_DUT "rawi2c /dev/i2c-1 r 0x31 64 24"`

	    printf "\n---   MP2   ---\n"
	    ./parse_i2c_opto_power.py `ssh $CTP7_DUT "rawi2c /dev/i2c-1 r 0x32 64 24"`

	    printf "\n---  CXP0   ---\n"
	    ./parse_i2c_opto_power.py `ssh $CTP7_DUT "rawi2c /dev/i2c-2 r 0x54 206 24"`

	    printf "\n---  CXP1   ---\n"
	    ./parse_i2c_opto_power.py `ssh $CTP7_DUT "rawi2c /dev/i2c-3 r 0x54 206 24"`

	    printf "\n---  CXP2   ---\n"
	    ./parse_i2c_opto_power.py `ssh $CTP7_DUT "rawi2c /dev/i2c-4 r 0x54 206 24"`

