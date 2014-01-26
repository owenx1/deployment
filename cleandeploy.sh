#!/usr/bin/bash
SANDBOX=sandbox_$RANDOM
echo Using sandbox $SANDBOX
#
# Stop services
/etc/init.d/apache2 stop
/etc/init.d/mysql stop
#
apt-get update
#
apt-get -q -y remove apache2
apt-get -q -y install apache2
#
apt-get -q -y remove mysql-server mysql-client
echo mysql-server mysql-server/root_password password password | debconf-set-selections
echo mysql-server mysql-server/root_password_again password password | debconf-set-selections
apt-get -q -y install mysql-server mysql-client
#
cd /tmp
mkdir $SANDBOX
cd $SANDBOX/
git clone https://github.com/FSlyne/NCIRL.git
cd NCIRL/
#
cp Apache/www/* /var/www/
cp Apache/cgi-bin/* /usr/lib/cgi-bin/
chmod a+x /usr/lib/cgi-bin/*
#
# Start services
/etc/init.d/apache2 start
/etc/init.d/mysql start
#
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

