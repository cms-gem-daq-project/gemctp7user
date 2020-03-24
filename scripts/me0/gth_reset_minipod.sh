#!/bin/sh

gth_rst_ch0_base_addr=0x69002404

gth_rst_addr=$gth_rst_ch0_base_addr

for i in $(seq 36 1 63)
do
	# Reset both RX and TX GTH
	mpoke $gth_rst_addr 3
	gth_rst_addr=$(($gth_rst_addr+256))
done
