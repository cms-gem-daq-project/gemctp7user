#!/bin/sh

addr=$((0x64000000 + ($1 << 2)))

printf 'mpoke 0x%x\n' $addr
mpoke $addr $2

