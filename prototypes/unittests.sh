#!/bin/bash

#functions
function isApacheRunning {
        isRunning apache2
        return $?
}

function isRunning {
PROCESS_NUM=$(ps -ef | grep "$1" | grep -v "grep" | wc -l)
if [ $PROCESS_NUM -gt 0 ] ; then
        echo $PROCESS_NUM
        return 1
else
        return 0
fi
}

#test apache
isApacheRunning
if [ "$?" -eq 1 ]; then
        echo "Apache process is Running, we're good"
else
        echo "Apache process is not Running, increase error count"
fi

#stop apahce 
/etc/init.d/apache2 stop

isApacheRunning
if [ "$?" -eq 1 ]; then
        echo "Apache process is Running, bad, increase errorcount"
else
        echo "Apache is not running, we're good"
fi

#start apache again

/etc/init.d/apache2 start


