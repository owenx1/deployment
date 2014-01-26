#!/bin/bash

#not needed
fname="deploylog$(date +%s).log"
touch $fname
logfile="/home/testuser/$fname"
echo "begin log file" >> $logfile

#functions - not needed
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

###not needed
function isMysqlRunning {
        isRunning mysqld
        return $?
}

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
        echo no change in files, doing nothing and exiting
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

##INSERT TESTS HERE

###
tar -zcvf webpackage_preDeploy.tgz webpackage
# DEPLOY
##Deemed deployment ready, check to 
if [ $ERRORCHECK -eq 0 ]; then
	echo "[$(date +%s)]Pushing to production" | tee -a $logfile
	#for f in *.html; do cp $f /var/www  ; done
	#for f in *.pl; do cp $f  /usr/lib/cgi-bin  ; done
	echo "[$(date +%s)]Adding to github" | tee -a $logfile
        mv webpackage_preDeploy.tgz ../deploy
        rm -rf webpackage
        cd ../deploy
        tar -zxvf webpackage_preDeploy.tgz
	#push to github
	cd webpackage
	git init 
	git add .
	git commit -m "[$(date +%s)]commit"
	git remote add origin https://github.com/owenx1/newsite.git
	git push -u origin master
	echo "$(date +%s)Site deployed, see monitorlog.txt for 15 minute updates"
else
	echo "[$(date +%s)]Cannot deploy due to $ERRORCHECK error(s) found during build-integrate-test phase. See $logfile for logged errors" | tee -a $logfile
	echo "[$(date +%s)]Site remains the same. Not pushing to github or production" | tee -a $logfile

fi

