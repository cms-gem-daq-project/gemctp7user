#!/bin/sh

while true
do
  date >> loopback_test.txt
  python2 ~/apps/reg_interface/reg_interface.py -e readKW GEM_TESTS.8b10b >> loopback_test.txt
  sleep 60
done
