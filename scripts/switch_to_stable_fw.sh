#!/bin/sh

ln -sf $HOME/gem_amc_top_v153_stress_test.xml $HOME/gem_amc_top.xml
ln -sf $HOME/tamu/gem_ctp7_v1_5_3_stress_test_9xOH_8b10b.bit $HOME/tamu/gem_ctp7.bit

cd $HOME/tamu
$HOME/tamu/cold_boot.sh 
#$HOME/tamu/cold_boot_invert_tx.sh 
