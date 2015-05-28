#!/usr/bin/env perl
use strict;
use warnings;
use FindBin qw($Bin);
use Getopt::Long;
use File::Copy;

use StackIt::DB::Config;

my ($help, $cidr, $subnet, $password);
my $ips = 254;
my $range_start = 5;
my $range_end = 254;

my $config_file = '/var/www/html/stack-it/stackit.conf';

my $result = GetOptions(
  'help|h'        => \$help,
  'cidr=s'        => \$cidr,
  'subnet|s=s'    => \$subnet,
  'ip-count|c=i'  => \$ips,
  'range-start=i' => \$range_start,
  'range-end=i'   => \$range_end,
  'config|C=s'    => \$config_file,
  'password|p=s'  => \$password
);

&usage(0) if($help);
&usage(1, $0 . ' should only be run as root') unless($ENV{'USER'} eq 'root');
&usage(1, 'Missing required parameter:  subnet') unless($subnet);
&usage(1, 'Missing required parameter:  cidr') unless($cidr);
&usage(1, 'Missing required parameter:  ips') unless($ips);

&loadDB($password);
&loadRoles();
&changeIps($ips, $cidr);
&changeStackItConf($subnet, $config_file, $cidr);

exit 0;

sub loadDB {
  my ($password) = @_;
  my $command = "$Bin/stack-it-migrations-migrate";

  $command .= " -p $password" if($password);
  system("$command");
}

sub loadRoles {
  system("$Bin/stack-it-load-roles");
}

sub changeIps {
  my ($iterations, $cidr) = @_;
  my @octets = split(/\./, $cidr);

  my $dbh = StackIt::DB::Config->new->connect;
  local $dbh->{AutoCommit} = 1;
  local $dbh->{RaiseError} = 1;

  my $sql = "INSERT INTO `private_ip` (`private_ip`, `active`) VALUES (?, ?)";
  my $sth = $dbh->prepare($sql) || die $dbh->errstr;

  $dbh->do("DELETE FROM `private_ip`");

  for my $x (1..$iterations) {
    my $ip = join('.', $octets[0], $octets[1], $octets[2], $x);
    my $available = ($x >= $range_start && $x <= $range_end);
    my $active = $available ? 0 : 1;
    $sth->execute($ip, $active);
  }
}

sub changeStackItConf {
  my ($subnet, $config, $cidr) = @_;

  open(FILE, '<' . $config) || die "$!";
  open(TMP, '>' . $config. '.tmp') || die "$!";

  while(my $line = <FILE>) {
    if($line =~ m/^instance_subnet_id/) {
      print TMP 'instance_subnet_id ' . $subnet . "\n";
    } elsif($line =~ m/^instance_subnet/) {
      print TMP 'instance_subnet    ' . $cidr . "\n";
    }else {
      print TMP $line;
    }
  }

  close(TMP);
  close(FILE);

  my $user = getpwnam "apache";
  my $group = getgrnam "apache";

  move($config . '.tmp', $config);
  chmod 0640, $config;
  chown $user, $group, $config;

  system('/sbin/service httpd restart');
}

sub usage {
  my ($exit_status, $msg) = @_;

  if($msg) {
    print "\n";
    print $msg . "\n";
  }

  print "\n";
  print 'Usage:  ' . $0 . ' <options>' . "\n";
  print "\n";
  print "\t" . '--help|-h      Print this help message' . "\n";
  print "\t" . '--subnet|s     AWS subnet id' . "\n";
  print "\t" . "--cidr         CIDR of AWS subnet" . "\n";
  print "\t" . '--ip-count|-c  The number of address to add to the private_ip table' . "\n";
  print "\t" . '--range-start  Fourth octet index to start creating inactive ip records' . "\n";
  print "\t" . '--range-end    Fourth octet index to end creating inactive ip records' . "\n";
  print "\t" . "--config|-C    Path to stackit.conf (default $config_file)" . "\n";
  print "\t" . "--password|-p  MySQL password for the root account" . "\n";
  print "\n";
  exit $exit_status;
}
