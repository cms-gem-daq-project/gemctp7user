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
NOW=$(date +"%H-%M-%m-%d-%Y")
echo "nohup ipbus 2>&1 > ${HOME}/logs/ipbus_${NOW}.log"
nohup ipbus 2>&1 > ${HOME}/logs/ipbus_${NOW}.log

echo "Restarting the RPC service"
killall rpcsvc
rpcsvc
