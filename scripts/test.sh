#!/bin/sh

REQUEST=$1

set -- "GEM_AMC.GEM_SYSTEM.BOARD_ID:$(( (`mpeek 0x66400008` & 0x0000ffff) >> 0 ))"\
        "GEM_AMC.TRIGGER.OH2.DEBUG_LAST_CLUSTER_0:$(( (`mpeek 0x66000c40` & 0x0000ffff) >> 0 ))"

for reg; do
  KEY=${reg%%:*}
  case $KEY in
     *$REQUEST*) printf '%s            = 0x%x\n' $KEY ${reg#*:};;
  esac
#  VALUE=${reg#*:}
#  printf '%s		= 0x%x\n' $KEY $VALUE
done


#for animal in "${ARRAY[@]}" ; do
#    KEY=${animal%%:*}
#    VALUE=${animal#*:}
#    printf "%s likes to %s.\n" "$KEY" "$VALUE"
#done

#echo -e "${ARRAY[1]%%:*} is an extinct animal which likes to ${ARRAY[1]#*:}\n"

