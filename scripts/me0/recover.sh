#!/bin/sh

source ~/.profile
source ~/.bashrc

PATH=$(dirname "$0"):${PATH}

cd $(dirname "$0")

echo "Reconfiguring Virtex7"
cold_boot_invert_cxp_rx.sh

echo "Load OH FW to the RAM for promless progamming"
source /mnt/persistent/gemdaq/gemloader/gemloader_configure.sh

echo "Restarting the ipbus service"
killall ipbus
sleep 1
restart_ipbus.sh

echo "Restarting the RPC service"
killall rpcsvc
sleep 1
rpcsvc
