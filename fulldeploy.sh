#!/bin/bash

#error count variable  to be used throughout
ERRORCOUNT=0

#begin process, create log file
echo "beginning deployment process"
echo "ceating log file"
fname="deploylog$(date +%s).log"
touch $fname
logfile="/home/testuser/$fname"
echo "begin log file" >> $logfile
echo "---------------------" >> $logfile

#Functions for checking CPU,Memory,IO, 
function checkCPU {
cpu_limit="80"
#echo $cpu_limit
cpu_usage=$(vmstat | awk 'NR==3{print $13 + $14}')
#echo $cpu_usage
if [[ $cpu_usgae -gt $cpu_limit ]]; then
     #  echo "CPU is too high"
        return 0
else
     #  echo "CPU at acceptable level"
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
io_limit="1000"
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
cs_limit="1000"
#echo $mem_free
if [[ $cs -gt $cs_limit ]] ; then
     #  echo "Context switching is an unacceptable level"
        return 0
else
     #  echo "Context Switching is at an acceptable level"
        return 1
fi
}

#Run environment checks
#---------------------------------------------------
echo "checking environment before clean deploy"
echo "[$(date +%s)]checking environemnt pre-clean deploy" >> $logfile
checkCPU
if [ "$?" -eq 1 ]; then
        echo "CPU is at an acceptable level"
	echo "[$(date +%s)]CPU is at an acceptable level" >> $logfile
else
        echo "CPU is too high"
	echo "[$(date +%s)]CPU is too high" >> $logfile
        ERRORCOUNT=$((ERRORCOUNT+1))
fi

checkMemory
if [ "$?" -eq 1 ]; then
        echo "There is sufficient memory available"
	echo "[$(date +%s)]There is sufficient memory available" >> $logfile
else
        echo "There is insufficient memory available"
	echo "[$(date +%s)]There is insufficient memory available" >> $logfile
        ERRORCOUNT=$((ERRORCOUNT+1))
fi

checkIO
if [ "$?" -eq 1 ]; then
        echo "IO is at an acceptable level"
	echo "[$(date +%s)]IO is at an acceptable level" >> $logfile
else
        echo "IO is at an unacceptable level"
	echo "[$(date +%s)]IO is at an unacceptable level" >> $logfile
        ERRORCOUNT=$((ERRORCOUNT+1))
fi

checkSwap
if [ "$?" -eq 1 ]; then
        echo "Swap rate is acceptable"
	 echo "[$(date +%s)]Swap rate is acceptable" >> $logfile
else
        echo "Swap rate is too high"
	echo "[$(date +%s)]Swap rate is too high" >> $logfile
        ERRORCOUNT=$((ERRORCOUNT+1))
fi

checkCS
if [ "$?" -eq 1 ]; then
        echo "Context Switching is at an acceptable level"
	echo "[$(date +%s)]Context Switching is at an acceptable level" >> $logfile
else
        echo "Context Switching is unacceptably high"
	echo "[$(date +%s)]Context Switching is unacceptably high" >> $logfile
        ERRORCOUNT=$((ERRORCOUNT+1))
fi

#########Stop if the environment is not redy########
if [ $ERRORCOUNT -gt 0 ]
then
        echo "[$(date +%s)]Environment is not ready for deployment. See sbove for details" | tee -a $logfile
        exit
fi


##################CLEAN DEPLOYMENT#################################
#------------------------------------------

echo "beginng full clean deployment" | tee -a $logfile

SANDBOX=sandbox_$RANDOM
echo Using sandbox $SANDBOX
#
# Stop services
echo "[$(date +%s)]stopping apache and mysql" >> $logfile
/etc/init.d/apache2 stop
/etc/init.d/mysql stop
#
apt-get update
#quietly remove and install apache
echo "[$(date +%s)]uninstalling apache" >> $logfile
apt-get -q -y remove apache2
echo "[$(date +%s)]installing apache" >> $logfile
apt-get -q -y install apache2
#quietly remove and install mysql
echo "[$(date +%s)]uninstalling mysql" >> $logfile
apt-get -q -y remove mysql-server mysql-client
echo mysql-server mysql-server/root_password password password | debconf-set-selections
echo mysql-server mysql-server/root_password_again password password | debconf-set-selections
echo "[$(date +%s)]installing mysql" >> $logfile
apt-get -q -y install mysql-server mysql-client
#display installation information
echo "[$(date +%s)]apache installed to $(which apache2)" | tee -a $logfile
echo "[$(date +%s)]MySql installed to $(which mysql)" | tee -a $logfile 
#retrieve files from github
echo "[$(date +%s)]Cloning from github" | tee -a $logfile
cd /tmp
mkdir $SANDBOX
cd $SANDBOX/
git clone https://github.com/FSlyne/NCIRL.git
cd NCIRL/
#add to directories
echo "[$(date +%s)]Adding to directories" | tee -a $logfile
cp Apache/www/* /var/www/
cp Apache/cgi-bin/* /usr/lib/cgi-bin/
chmod a+x /usr/lib/cgi-bin/*
#
# Start services
echo "[$(date +%s)]Starting services" | tee -a $logfile
/etc/init.d/apache2 start
/etc/init.d/mysql start
#Testing  database
cat <<FINISH | mysql -uroot -ppassword
drop database if exists dbtest;
CREATE DATABASE dbtest;
GRANT ALL PRIVILEGES ON dbtest.* TO dbtestuser@localhost IDENTIFIED BY 'dbpassword';
use dbtest;
drop table if exists custdetails;
create table if not exists custdetails (
name         VARCHAR(30)   NOT NULL DEFAULT '',
address         VARCHAR(30)   NOT NULL DEFAULT ''
);
insert into custdetails (name,address) values ('John Byrne','Street Address'); select * from custdetails;
FINISH
#
cd /tmp
rm -rf $SANDBOX

#Begin log and monitor process
#----------------------------
echo "[$(date +%s)]Starting log/monitoring function" | tee -a $logfile

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

# Functional Body of monitoring script <----------------------------

isApacheRunning
if [ "$?" -eq 1 ]; then
        echo "[$(date +%s)]Apache process is Running" | tee -a $logfile 
else
        echo "[$(date +%s)]Apache process is not Running" | tee -a $logfile
        ERRORCOUNT=$((ERRORCOUNT+1))
        ERRORSTRING="$ERRORSTRING \n Apache not running|||||"
fi

isApacheListening
if [ "$?" -eq 1 ]; then
        echo "[$(date +%s)]Apache is Listening" | tee -a $logfile
else
        echo "[$(date +%s)]Apache is not Listening" | tee -a $logfile
        ERRORCOUNT=$((ERRORCOUNT+1))
        ERRORSTRING="$ERRORSTRING  Apache not listening|||||  "
fi

isApacheRemoteUp
if [ "$?" -eq 1 ]; then
        echo "[$(date +%s)]Remote Apache TCP port is up" | tee -a $logfile
else
        echo "[$(date +%s)]Remote Apache TCP port is down" | tee -a $logfile
        ERRORCOUNT=$((ERRORCOUNT+1))
	 ERRORSTRING="$ERRORSTRING  Apache TCP port is down|||||  "
fi

isMysqlRunning
if [ "$?" -eq 1 ]; then
        echo "[$(date +%s)]Mysql process is Running" | tee -a $logfile
else
        echo "[$(date +%s)]Mysql process is not Running" | tee -a $logfile
        ERRORCOUNT=$((ERRORCOUNT+1))
	 ERRORSTRING="$ERRORSTRING  MySQL process is not running|||||  "
fi

isMysqlListening
if [ "$?" -eq 1 ]; then
        echo "[$(date +%s)]Mysql is Listening" | tee -a $logfile
else
        echo "[$(date +%s)]Mysql is not Listening" | tee -a $logfile
	 ERRORSTRING="$ERRORSTRING  MYSQL is not listening|||||  "
        ERRORCOUNT=$((ERRORCOUNT+1))
fi

isMysqlRemoteUp
if [ "$?" -eq 1 ]; then
        echo "[$(date +%s)]Remote Mysql TCP port is up" | tee -a $logfile
else
        echo "[$(date +%s)]Remote Mysql TCP port is down" | tee -a $logfile
        ERRORCOUNT=$((ERRORCOUNT+1))
	ERRORSTRING="$ERRORSTRING  Remote MySQL port is down|||||  "
fi

if  [ $ERRORCOUNT -gt 0 ]
then
        echo "There is a problem with Apache or Mysql" | perl /home/testuser/sendemail.pl $ERRORSTRING
fi

#------end run of level 0 functions

###############Stop and exit if the initial monitor has produced errors######
if [ $ERRORCOUNT -gt 0 ]
then
        echo "[$(date +%s)Monitoring has found that components are not read for deployment. See sbove for details" | tee -a $logfile
        exit
fi


##------------------BEGIN BUILD, INTEGRATE AND TEST-----------------------##

#set up variable for counting errors
ERRORCHECK=0

#set up function for checking if features exist
function exists {
to_find=$(which $feature | grep / | wc -l)
if [ $to_find -gt 0 ] ; then
        echo "[$(date +%s)]$feature exists in" $(which $feature) | tee -a $logfile
else
        echo "[$(date +%s)]$feature does not appear to be installed" | tee -a $logfile
        ERRORCHECK=$((ERRORCHECK+$errs))
fi
}

#check if helper functions are installed to perfrom quality control
echo "[$(date +%s)]Checking for quality control functions" | tee -a $logfile
feature="tidy"
exists
feature="linkchecker"
exists
#navigate to tmp directory
cd /tmp
#create sandbox
SANDBOX=sandbox_$RANDOM
mkdir $SANDBOX
cd $SANDBOX
# Make test webpackage
mkdir webpackage
#add content to webpackage from git
git clone https://github.com/owenx1/newstatic.git
mv /tmp/$SANDBOX/newstatic/* /tmp/$SANDBOX/webpackage
rm -rf newstatic
echo "[$(date +%s)]New content pulled from server" | tee -a $logfile
#touch webpackage/index.htm
#touch webpackage/form.htm
#touch webpackage/script1.plx
#touch webpackage/script2.plx
#
# Make the process directories
mkdir build
mkdir integrate
mkdir test
mkdir deploy
#
# Make webpackage and move webpackage
#
tar -zcvf webpackage_preBuild.tgz webpackage
MD5SUM=$(md5sum webpackage_preBuild.tgz | cut -f 1 -d' ')
PREVMD5SUM=$(cat /tmp/md5sum)
FILECHANGE=0
if [[ "$MD5SUM" != "$PREVMD5SUM" ]]
then
        FILECHANGE=1
        echo $MD5SUM not equal to $PREVMD5SUM
else
        FILECHANGE=0
        echo $MD5SUM equal to $PREVMD5SUM
fi
echo $MD5SUM > /tmp/md5sum
if [ $FILECHANGE -eq 0 ]
then
        echo "no change in files, doing nothing and exiting" | tee -a $logfile
        exit
fi
# BUILD
mv webpackage_preBuild.tgz build
rm -rf webpackage
cd build
#unpack, find number of files to be added
tar -zxvf webpackage_preBuild.tgz
cd webpackage
numfiles=$(ls -l | wc -l)
numfiles=$((numfiles-1))
ls -l
echo "[$(date +%s)]There are $numfiles file(s) to be added to the site" | tee -a $logfile
#set up log file for html tidy output
lname="tidylog$(date +%s).log"
touch $fname /home/testuser/
tidyfile="/home/testuser/$lname"
echo "begin tidy" >> $tidyfile
echo "-----------------" >> $tidyfile
#tidy the html from the static files, write detailed output to logfile
for f in *.html; do tidy -f $tidyfile -m $f ; done
echo "[$(date +%s)]HTML files have been tidied, see tidylog for details" | tee -a $logfile
echo "[$(date +%s)]Build conditions satisfied, moving to integration phase" | tee -a $logfile
cd ..
#
tar -zcvf webpackage_preIntegrate.tgz webpackage
# INTEGRATE
mv webpackage_preIntegrate.tgz ../integrate
rm -rf webpackage
cd ../integrate
#
tar -zxvf webpackage_preIntegrate.tgz
#pull site from github
git clone https://github.com/owenx1/thesite.git
#output differences
echo "looking at files to be added"
#DEBUG
#ls -l
pwd
echo "[$(date +%s)]directory differences are" >>$logfile
diff -i -w -B /tmp/$SANDBOX/integrate/thesite /tmp/$SANDBOX/integrate/webpackage >>$logfile
diff /tmp/$SANDBOX/integrate/thesite /tmp/$SANDBOX/integrate/webpackage
#move all files to the same folder
mv /tmp/$SANDBOX/integrate/thesite/* /tmp/$SANDBOX/integrate/webpackage
#move into folder
cd webpackage
#set up log file for logging broken links
filename="linklog$(date +%s).log"
touch $filename
linkfile="/home/testuser/$filename"
echo "begin log file of links" >> $linkfile
echo "-----------------------" >> $linkfile
#search pages for broken links, output errors to logfile and screen
echo "[$(date +%s)]checking site for broken links" | tee -a $logfile
for f in *.html; do linkchecker $f | tee -a $linkfile ; done
#write output to log
##find number of errors
errs=0
TOTALERRORS=0
for f in *.html; do errs=$(linkchecker $f | grep Error: | grep -v cgi-bin | wc -l); TOTALERRORS=$((TOTALERRORS+$errs))  ; done
###
echo $TOTALERRORS "error(s) found while checking links. See $linkfile for details" | tee -a $logfile
ERRORCHECK=$((ERRORCHECK+$TOTALERRORS))
#check for all dependencies needed for site to function
echo "searching for dependencies needed for successful deployment"
feature="apache2"
exists
feature="mysql"
exists
feature="perl"
exists
feature="git"
exists
#move out of webpackage folder
cd ..
#tar up webpackage and proceed to testing phase
tar -zcvf webpackage_preTest.tgz webpackage
echo "[$(date +%s)]Integration stage completed moving to test phase" | tee -a $logfile
#ERRORCHECK=0
# TEST
mv webpackage_preTest.tgz ../test
rm -rf webpackage
cd ../test
#
tar -zxvf webpackage_preTest.tgz
##package compnents built and integrated, time to test the deployment components
########################BEGIN UNIT TESTS#######################################
#Unit test for apache: stop + start and verify behaviour
echo "[$(date +%s)]Beggining unit tests" | tee -a $logfile
echo "[$(date +%s)]Unit testing apache" | tee -a $logfile

isApacheRunning
if [ "$?" -eq 1 ]; then
        echo "Apache process is Running. Test passed" | tee -a $logfile
else
        echo "Apache process is not Running. Test failed" | tee -a $logfile
        ERRORCHECK=$((ERRORCHECK+1))
fi

#stop apache
echo "[$(date +%s)]Stopping Apache" | tee -a $logfile
/etc/init.d/apache2 stop

isApacheRunning
if [ "$?" -eq 1 ]; then
        echo "Apache process is Running. Test Failed" | tee -a $logfile
        ERRORCHECK=$((ERRORCHECK+1))
else
        echo "Apache is not running. Test passed" | tee -a $logfile
fi

#start apache again
echo "[$(date +%s)]Starting apache again" | tee -a $logfile

/etc/init.d/apache2 start

##Unit testing MySql
echo "[$(date +%s)]Unit testing mysql" | tee -a $logfile

isMysqlRunning
if [ "$?" -eq 1 ]; then
        echo "Mysql process is Running. Test passed" | tee -a $logfile
else
        echo "Mysql process is not Running. Test failed" | tee -a $logfile
        ERRORCHECK=$((ERRORCHECK+1))
fi

#stop mysql
echo "[$(date +%s)]Stopping Mysql" | tee -a $logfile
/etc/init.d/mysql stop

isMysqlRunning
if [ "$?" -eq 1 ]; then
        echo "Mysql process is Running. Test Failed" | tee -a $logfile
        ERRORCHECK=$((ERRORCHECK+1))
else
        echo "Mysql is not running. Test passed" | tee -a $logfile
fi

#start mysql again
echo "[$(date +%s)]Starting mysql again" | tee -a $logfile

/etc/init.d/mysql start

##########################END UNIT TESTS#######################################
echo "[$(date +%s)]Unit tests complete" | tee -a $logfile

##Begin  final Environment acceptance tests to ensure infratructure is ready for deployment
echo "[$(date +%s)]Beginning final environment acceptance tests" | tee -a $logfile
######################START EAT TESTS################################################

#Run environment checks
#---------------------------------------------------
echo "checking environment before final deployment"
echo "[$(date +%s)]checking environemnt pre-clean deploy" >> $logfile
checkCPU
if [ "$?" -eq 1 ]; then
        echo "CPU is at an acceptable level"
        echo "[$(date +%s)]CPU is at an acceptable level" >> $logfile
else
        echo "CPU is too high"
        echo "[$(date +%s)]CPU is too high" >> $logfile
        ERRORCHECK=$((ERRORCHECK+1))
fi

checkMemory
if [ "$?" -eq 1 ]; then
        echo "There is sufficient memory available"
        echo "[$(date +%s)]There is sufficient memory available" >> $logfile
else
        echo "There is insufficient memory available"
        echo "[$(date +%s)]There is insufficient memory available" >> $logfile
        ERRORCHECK=$((ERRORCHECK+1))
fi

checkIO
if [ "$?" -eq 1 ]; then
        echo "IO is at an acceptable level"
        echo "[$(date +%s)]IO is at an acceptable level" >> $logfile
else
        echo "IO is at an unacceptable level"
        echo "[$(date +%s)]IO is at an unacceptable level" >> $logfile
        ERRORCHECK=$((ERRORCHECK+1))
fi

checkSwap
if [ "$?" -eq 1 ]; then
        echo "Swap rate is acceptable"
         echo "[$(date +%s)]Swap rate is acceptable" >> $logfile
else
        echo "Swap rate is too high"
        echo "[$(date +%s)]Swap rate is too high" >> $logfile
        ERRORCHECK=$((ERRORCHECK+1))
fi

checkCS
if [ "$?" -eq 1 ]; then
        echo "Context Switching is at an acceptable level"
        echo "[$(date +%s)]Context Switching is at an acceptable level" >> $logfile
else
        echo "Context Switching is unacceptably high"
        echo "[$(date +%s)]Context Switching is unacceptably high" >> $logfile
        ERRORCHECK=$((ERRORCHECK+1))
fi

echo "[$(date +%s)]Environment checks complete, results shown above" | tee -a $logfile

###
tar -zcvf webpackage_preDeploy.tgz webpackage
# DEPLOY
##Deemed deployment ready, check to
if [ $ERRORCHECK -eq 0 ]; then
	 mv webpackage_preDeploy.tgz ../deploy
        rm -rf webpackage
        cd ../deploy
        tar -zxvf webpackage_preDeploy.tgz
        cd webpackage
	#backup old version of site
	#git clone https://github.com/owenx1/thesite.git
	#foldername="[$(date +%s)]Version"
	#mv -f thesite /home/testuser/archive/thesite/$foldername 
        echo "[$(date +%s)]Pushing to production" | tee -a $logfile
        for f in *.html; do cp $f /var/www  ; done
        for f in *.pl; do cp $f  /usr/lib/cgi-bin  ; done
        echo "[$(date +%s)]Adding to github" | tee -a $logfile
        #push to github
   	#cd webpackage
        git init
        git add .
        git commit -m "[$(date +%s)]commit"
        git remote add origin https://github.com/owenx1/newsite.git
        git push -u origin --force master
        echo "$(date +%s)Site deployed, see monitorlog.txt for 15 minute updates"
else
        echo "[$(date +%s)]Cannot deploy due to $ERRORCHECK error(s) found during build-integrate-test phase. See $logfile for logged errors" | tee -a $logfile
        echo "[$(date +%s)]Site remains the same. Not pushing to github or production" | tee -a $logfile

fi



