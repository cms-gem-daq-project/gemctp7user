#!/bin/sh

while [ true ]
do
   mpoke 0x6201c000 1
   echo "Red"
   
    sleep 1

    mpoke 0x6201c000 2
    echo "Blue"

    sleep 2

done
