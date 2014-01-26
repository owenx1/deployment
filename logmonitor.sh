#!/bin/bash
# fslyne 2013

#ADMINISTRATOR=byrneo5@gmail.com
#MAILSERVER=smpt.gmail.com
ERRORSTRING=""

# Level 1 functions <---------------------------------------


function isApacheRunning {
        isRunning apache2
        return $?
}

function isApacheListening {
        isTCPlisten 80
        return $?
}

function isMysqlListening {
        isTCPlisten 3306
        return $?
}

function isApacheRemoteUp {
        isTCPremoteOpen 127.0.0.1 80
        return $?
}

function isMysqlRunning {
        isRunning mysqld
        return $?
}

function isMysqlRemoteUp {
        isTCPremoteOpen 127.0.0.1 3306
        return $?
}

# Level 0 functions <--------------------------------------

function isRunning {
PROCESS_NUM=$(ps -ef | grep "$1" | grep -v "grep" | wc -l)
if [ $PROCESS_NUM -gt 0 ] ; then
        echo $PROCESS_NUM
        return 1
else
        return 0
fi
}


function isTCPlisten {
TCPCOUNT=$(netstat -tupln | grep tcp | grep "$1" | wc -l)
if [ $TCPCOUNT -gt 0 ] ; then
        return 1
else
        return 0
fi
}

function isUDPlisten {
UDPCOUNT=$(netstat -tupln | grep udp | grep "$1" | wc -l)
if [ $UDPCOUNT -gt 0 ] ; then
        return 1
else
        return 0
fi
}


function isTCPremoteOpen {
timeout 1 bash -c "echo >/dev/tcp/$1/$2" && return 1 ||  return 0
}


function isIPalive {
PINGCOUNT=$(ping -c 1 "$1" | grep "1 received" | wc -l)
if [ $PINGCOUNT -gt 0 ] ; then
        return 1
else
        return 0
fi
}

function getCPU {
app_name=$1
cpu_limit="5000"
app_pid=`ps aux | grep $app_name | grep -v grep | awk {'print $2'}`
app_cpu=`ps aux | grep $app_name | grep -v grep | awk {'print $3*100'}`
if [[ $app_cpu -gt $cpu_limit ]]; then
     return 0
else
     return 1
fi
}


ERRORCOUNT=0

# Functional Body of monitoring script <----------------------------

##Write Timestamp
echo "$(date +%s)"

isApacheRunning
if [ "$?" -eq 1 ]; then
        echo Apache process is Running
else
        echo Apache process is not Running
        ERRORCOUNT=$((ERRORCOUNT+1))
	ERRORSTRING="$ERRORSTRING \n Apache not running|||||"
fi

isApacheListening
if [ "$?" -eq 1 ]; then
        echo Apache is Listening
else
        echo Apache is not Listening
        ERRORCOUNT=$((ERRORCOUNT+1))
	ERRORSTRING="$ERRORSTRING  Apache not listening|||||  "
fi

isApacheRemoteUp
if [ "$?" -eq 1 ]; then
        echo Remote Apache TCP port is up
else
        echo Remote Apache TCP port is down
        ERRORCOUNT=$((ERRORCOUNT+1))
fi

isMysqlRunning
if [ "$?" -eq 1 ]; then
        echo Mysql process is Running
else
        echo Mysql process is not Running
        ERRORCOUNT=$((ERRORCOUNT+1))
fi

isMysqlListening
if [ "$?" -eq 1 ]; then
        echo Mysql is Listening
else
        echo Mysql is not Listening
        ERRORCOUNT=$((ERRORCOUNT+1))
fi

isMysqlRemoteUp
if [ "$?" -eq 1 ]; then
        echo Remote Mysql TCP port is up
else
        echo Remote Mysql TCP port is down
        ERRORCOUNT=$((ERRORCOUNT+1))
fi


if  [ $ERRORCOUNT -gt 0 ]
then
        echo "There is a problem with Apache or Mysql" | perl sendemail.pl $ERRORSTRING
fi




