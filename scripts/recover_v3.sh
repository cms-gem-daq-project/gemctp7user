#!/bin/sh

source ~/.profile
source ~/.bashrc

echo cd $(dirname "$0")
cd $(dirname "$0")

echo "Reconfiguring Virtex7"
echo ./cold_boot_invert_tx.sh
./cold_boot_invert_tx.sh

echo "Set ignore TTC hard resets"
echo reg_interface.py -e write "GEM_AMC.SLOW_CONTROL.SCA.CTRL.TTC_HARD_RESET_EN 0"
reg_interface.py -e write "GEM_AMC.SLOW_CONTROL.SCA.CTRL.TTC_HARD_RESET_EN 0"

echo "Load OH FW to the RAM for promless progamming"
echo "./gemloader_configure.sh"
source /mnt/persistent/gemdaq/gemloader/gemloader_configure.sh

echo "Restarting the ipbus service"
killall ipbus
sleep 1
./restart_ipbus.sh

echo "Restarting the RPC service"
killall rpcsvc
sleep 1
rpcsvc
