#!/bin/sh

for i in `seq 1 700`
do
        mpoke 0x62011008 1
done

sleep 1

mpoke 0x62011010 1
mpoke 0x62011030 1

echo ""
echo -n "BC Clock Lock          :"; mpeek 0x62011004;
echo -n "BC0 Lock               :"; mpeek 0x62011014
echo -n "TTC Single Error Count :"; mpeek 0x62011034;
echo -n "TTC Double Error Count :"; mpeek 0x62011038;
echo ""

