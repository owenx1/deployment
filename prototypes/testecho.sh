echo "beginning deployment process"
echo "ceating log file"
fname="deploylog$(date +%s).log"
touch $fname
logfile="/home/testuser/$fname"
echo $logfile
echo "begin log file" >> $logfile
echo "---------------------" >> $logfile

