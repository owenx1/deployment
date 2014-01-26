#!/usr/bin/perl
# fslyne 2013
#use Net::SMTP::TLS;

#my $subj="Mailer message - ".convdatetimenow();
#my $mailserver='smtp.gmail.com';
#my $to=shift @ARGV;
#my $from=$to;
#my $m = shift @ARGV;
#$mailserver=($m) ? $m : $mailserver;

# set up access to mailserver;
#$smtp = Net::SMTP::TLS->new($mailserver)
use strict;
  use warnings;
  use Email::Send;
  use Email::Send::Gmail;
  use Email::Simple::Creator;

  my $body = "";
  my $counter = 1;

foreach my $a(@ARGV) {
        $body = $body . $a;
	$counter++;
}

  my $email = Email::Simple->create(
      header => [
          From    => 'owentest365@gmail.com',
          To      => 'owentest365@gmail.com',
          Subject => 'Server down',
      ],
      body => $body,
  );

  my $sender = Email::Send->new(
      {   mailer      => 'Gmail',
          mailer_args => [
              username => 'owentest365@gmail.com',
              password => 'x13117343',
          ]
      }
  );
  eval { $sender->send($email) };
  die "Error sending email: $@" if $@;

 
#$smtp->mail($from);
#$smtp->to($to);
#$smtp->data();
#$smtp->datasend("From: $from\n");
#$smtp->datasend("To: $to\n");
#$smtp->datasend("Subject: $subj\n");
#$smtp->datasend("\n");
#while(<STDIN>) {
#        $smtp->datasend($_);
#}
#$smtp->dataend();
#$smtp->quit;
#
#exit;

sub convdatetimenow {
return convdatetime(time());
}

sub convdatetime {
my $time = shift;
return convdate($time)." ".convtime($time);
}

sub convdate {
my $time = shift;
my ($sec,$min,$hour,$day,$mon,$year,$wday,$yday,$isdst)=localtime($time);
$year = "1900"+$year;
$mon = $mon+1; $mon = "0".$mon if ($mon<10);
$day = "0".$day if ($day<10) ;
return "$year-$mon-$day";
}


sub convtime {
my $time = shift;
my ($sec,$min,$hour,$day,$mon,$year,$wday,$yday,$isdst)=localtime($time);
$hour= "0".$hour if ($hour<10);
$min = "0".$min  if ($min <10);
$sec = "0".$sec  if ($sec <10);
return "$hour:$min:$sec";
}


