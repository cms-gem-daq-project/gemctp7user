#!/bin/sh

echo "checks OH #0 Track RX clock synchronization with CTP7 TTC clock. You should see Difference=0 all the time if these clocks have the same frequency."

# reset the counter
mpoke 0x65800000 0x40000000
mpoke 0x65800000 0x0

ITERATION=0
while [ $ITERATION -lt 10 ]; do
	COUNTS=`mpeek 0x65800040`                                                                              
	COUNT1=`printf '0x%x' $(( $COUNTS & 0x0000ffff ))`                                                     
	COUNT2=`printf '0x%x' $(( (($COUNTS & 0xffff0000) >> 16) & 0xffff ))`                                  
	DIFF=`printf '0x%x' $(( (($COUNT1 & 0xffff) - ($COUNT2 & 0xffff)) & 0xffff ))`
                                                                                                       
	echo $COUNTS                                                                                           
	echo $COUNT1                                                                                           
	echo $COUNT2 
	echo "Difference: $DIFF"

	sleep 1	

        let ITERATION=ITERATION+1
done


