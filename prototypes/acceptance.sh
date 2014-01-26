#!/bin/bash

ERRORCOUNT=0

function checkCPU {
cpu_limit="80"
#echo $cpu_limit
cpu_usage=$(vmstat | awk 'NR==3{print $13 + $14}')
#echo $cpu_usage
if [[ $cpu_usgae -gt $cpu_limit ]]; then
     #	echo "CPU is too high"
	return 0
else
     #	echo "CPU at acceptable level"
	return 1
fi
}

function checkMemory {
mem_limit="100000"
mem_free=$(vmstat | awk 'NR==3{print $4}')
#echo $mem_free
if [[ $mem_limit -gt $mem_free ]]; then
     #  echo "Not enough free memory"
        return 0
else
     #  echo "There is sufficient memory available"
        return 1
fi
}

function checkSwap {
swap_limit="5"
swap_in=$(vmstat | awk 'NR==3{print $7}')
swap_out=$(vmstat | awk 'NR==3{print $8}')
#echo $mem_free
if [[ $swap_in -gt $swap_limit ]] || [[ $swap_out -gt $swap_limit ]]  ; then
     #  echo "Swap rate is too high"
        return 0
else
     #  echo "Swap rate is an acceptable level"
        return 1
fi
}

function checkIO {
io_limit="100"
blocks_in=$(vmstat | awk 'NR==3{print $9}')
blocks_out=$(vmstat | awk 'NR==3{print $10}')
#echo $mem_free
if [[ $blocks_in -gt $io_limit ]] || [[ $blocks_out -gt $io_limit ]]  ; then
     #  echo "IO rate is too high"
        return 0
else
     #  echo "IO is at an acceptable level"
        return 1
fi
}

function checkCS { 
cs=$(vmstat | awk 'NR==3{print $12}')
cs_limit="100"
#echo $mem_free
if [[ $cs -gt $cs_limit ]] ; then
     #  echo "Context switching is an unacceptable level"
        return 0
else
     #  echo "Context Switching is at an acceptable level"
        return 1
fi
}



checkCPU
if [ "$?" -eq 1 ]; then
        echo "CPU is at an acceptable level"
else
        echo "CPU is too high"
        ERRORCOUNT=$((ERRORCOUNT+1))
fi
 
checkMemory
if [ "$?" -eq 1 ]; then
        echo "There is sufficient memory available"
else
        echo "There is insufficient memory available"
        ERRORCOUNT=$((ERRORCOUNT+1))
fi

checkIO
if [ "$?" -eq 1 ]; then
        echo "IO is at an acceptable level"
else
        echo "IO is at an unacceptable level"
        ERRORCOUNT=$((ERRORCOUNT+1))
fi

checkSwap
if [ "$?" -eq 1 ]; then
        echo "Swap rate is acceptable"
else
        echo "Swap rate is too high"
        ERRORCOUNT=$((ERRORCOUNT+1))
fi

checkCS
if [ "$?" -eq 1 ]; then
        echo "Context Switching is at an acceptable level"
else
        echo "Context Switching is unacceptably high"
        ERRORCOUNT=$((ERRORCOUNT+1))
fi

