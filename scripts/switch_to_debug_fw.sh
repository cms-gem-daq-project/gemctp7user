#!/bin/sh

#ln -sf $HOME/gem_amc_top_v1_5_15_2oh.xml $HOME/gem_amc_top.xml
#ln -sf $HOME/gem_amc_top_v1_7_3_2oh.xml $HOME/gem_amc_top.xml
ln -sf $HOME/gem_amc_top_v1_8_3_2oh.xml $HOME/gem_amc_top.xml # added MMCM unlock counter

#ln -sf $HOME/tamu/gem_ctp7_v1_7_1_2xOH_gbt_jtag_test18_pippm_phase_aligner.bit $HOME/tamu/gem_ctp7.bit
#ln -sf $HOME/tamu/gem_ctp7_v1_7_1_2xOH_gbt_jtag_test19_pippm_phase_aligner__correct_jtag_byte_order.bit $HOME/tamu/gem_ctp7.bit
#ln -sf $HOME/tamu/gem_ctp7_v1_7_3_2xOH_gbt_jtag_test20_pippm_phase_aligner.bit $HOME/tamu/gem_ctp7.bit
#ln -sf $HOME/tamu/gem_ctp7_v1_7_4_2xOH_gbt_jtag_test21_pippm_phase_aligner_no_ohgbt_sync.bit $HOME/tamu/gem_ctp7.bit
#ln -sf $HOME/tamu/gem_ctp7_v1_7_4_2xOH_gbt_jtag_test21_pippm_phase_aligner_tttttttttt_dly_bypass.bit $HOME/tamu/gem_ctp7.bit
#ln -sf $HOME/tamu/gem_ctp7_v1_7_4_gbt_ref_clk_test1.bit $HOME/tamu/gem_ctp7.bit
#ln -sf $HOME/tamu/gem_ctp7_v1_8_0_gbt_ref_clk_test2.bit $HOME/tamu/gem_ctp7.bit
#ln -sf $HOME/tamu/gem_ctp7_v1_8_1_ila_check_clk_phase_alignment.bit $HOME/tamu/gem_ctp7.bit
#ln -sf $HOME/tamu/gem_ctp7_v1_8_2_ila_check_clk_phase_alignment2.bit $HOME/tamu/gem_ctp7.bit
#ln -sf $HOME/tamu/gem_ctp7_v1_8_3_mmcm_unlock_counter.bit $HOME/tamu/gem_ctp7.bit
#ln -sf $HOME/tamu/gem_ctp7_v1_8_4_mmcm_shift_past_lock_and_shift_back.bit $HOME/tamu/gem_ctp7.bit
#ln -sf $HOME/tamu/gem_ctp7_v1_8_4_gbt_rx_sync_fifo_rd_en_delay.bit $HOME/tamu/gem_ctp7.bit
#ln -sf $HOME/tamu/gem_ctp7_v1_7_4_2xOH_pippm_phase_aligned_and_phase_check.bit $HOME/tamu/gem_ctp7.bit
#ln -sf $HOME/tamu/gem_ctp7_v1_8_5_mmcm_shift_past_lock_and_back.bit $HOME/tamu/gem_ctp7.bit
ln -sf $HOME/tamu/gem_ctp7_v1_8_6_12xOH_mmcm_clk_align_gbt_no_sync.bit $HOME/tamu/gem_ctp7.bit


cd $HOME/tamu
$HOME/tamu/cold_boot.sh 
