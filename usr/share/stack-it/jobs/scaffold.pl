#!/usr/bin/env perl

use strict;
use warnings;

use Proc::Pidfile;
use Cache::Memcached;
use Getopt::Long;

my $cacheServer = 'localhost';
my $cachePort   = 11211;
my $pidPath     = '/tmp/stack_it';

my $options = GetOptions(
  'server|s=s' => \$cacheServer,
  'port|p=i'   => \$cachePort
);

my $cache = new Cache::Memcached();
$cache->set_servers([ $cacheServer . ':' . $cachePort ]);

my $jobs = &getJobKeys($cache, $cacheServer, $cachePort);

foreach my $job (values %{$jobs}) {
  my $pid = fork();

  if($pid) {
    waitpid $pid, 0;
  } elsif($pid == 0) {
    # Before we do anything else, we create a pid file to prevent concurrency.
    # if the pidfile already exists, this will exit silently here:
    my $ppObj = new Proc::Pidfile(
      'silent'  => 1,
      'pidfile' => "$pidPath/$job"
    );

    print "Processing job $job\n";

    my $job_data = $cache->get($job);

    exit 1 unless($job_data);

    foreach my $class (keys %{$job_data}) {
      eval "require $class";
      new $class($job_data->{$class});
    }

    $cache->delete($job);

    # Kill our pid file...
    undef $ppObj;

    exit 0;
  } else {
    die "Cannot fork: $!";
  }
}

exit 0;

sub getJobKeys {
  my ($cacheObj, $server, $port) = @_;
  my $keys = {};

  my $uri = $server . ':' . $port;
  my $slabs = $cacheObj->stats('slabs');
  my @lines = split(/\r\n/, $slabs->{'hosts'}->{$uri}->{'slabs'});

  use Data::Dumper;

  foreach my $line (@lines) {
    if($line =~ m/^STAT\s+(\d+):/) {
      my $class = $1;

      if($keys->{$class}) {
        next;
      } else {
        my $dump = $cacheObj->stats("cachedump $1 1");
        my $value = $dump->{'hosts'}->{$uri}->{"cachedump $1 1"};

        if($value =~ m/^ITEM\s+(stackit-job-\S+)/) {
          $keys->{$class} = $1;
        }
      }
    }
  }

  return $keys;
}
