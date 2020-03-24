#!/bin/sh

source ~/.profile
source ~/.bashrc

echo cd $(dirname "$0")
cd $(dirname "$0")

echo "Reconfiguring Virtex7"
echo ./cold_boot.sh
./cold_boot.sh

echo "Restarting the ipbus service"
killall ipbus
sleep 1
./restart_ipbus.sh

echo "Restarting the RPC service"
killall rpcsvc
sleep 1
rpcsvc
