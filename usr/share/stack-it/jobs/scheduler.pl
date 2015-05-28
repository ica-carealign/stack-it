#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use Proc::Pidfile;
use Time::Local;
use Getopt::Long;
use Config::Simple;

use StackIt::Time;
use StackIt::AWS::EC2::Stop;
use StackIt::AWS::EC2::Start;
use StackIt::Collection::EC2::Schedule;
use StackIt::Collection::EC2::Instance;
use StackIt::AWS::EC2::Tag::Create;

my ($help, $configFile, $accessKey, $secretKey, $region);

my $DEBUG = 0;
my $instanceIDs = [];

my $result = GetOptions(
  'help|h'         => \$help,
  'config|c=s'     => \$configFile,
  'access-key|a=s' => \$accessKey,
  'secret-key|s=s' => \$secretKey,
  'region|r=s'     => \$region,
  'debug|d'        => \$DEBUG
);

&usage(0) if($help);

if($configFile) {
  if(-f $configFile) {
    my $config = new Config::Simple($configFile);

    $accessKey = $config->param('AccessKey');
    $secretKey = $config->param('SecretKey');
    $region    = $config->param('Region');
  } else {
    &usage(1, 'Cannot access ' . $configFile);
  }
}

&usage(1, 'access-key is required') unless($accessKey);
&usage(1, 'secret-key is required') unless($secretKey);
&usage(1, 'region is required')     unless($region);

# If the pidfile already exists, this will exit silently...
my $ppObj   = new Proc::Pidfile(silent => 1);

print localtime(time) . ' [Scheduler] Start Run...' .  "\n" if($DEBUG);

# Pull all schedule data...
my $schedules = &getSchedules($accessKey, $secretKey, $region);

print 'SCHEDULES: ' . Dumper($schedules) . "\n" if($DEBUG);

# Exit if there are no instances with a schedule...
unless(@{$schedules}) {
  undef $ppObj;
  exit 0;
}

foreach my $schedule (@{$schedules}) {
  push @{$instanceIDs}, $schedule->InstanceID;
}

print 'INSTANCE IDs: ' . Dumper($instanceIDs) . "\n" if($DEBUG);

# Using instance ids from the schedule data,
# grab instance data...
my $instances = &getInstances($accessKey, $secretKey, $region, $instanceIDs);

foreach my $instance (@{$instances}) {
  print 'INSTANCE: ' . Dumper($instance) . "\n" if($DEBUG);

  my $instanceSchedule = &getScheduleByInstanceID(
    $schedules,
    $instance->InstanceID
  );

  print 'INSTANCE SCHEDULE: ' . Dumper($instanceSchedule) . "\n" if($DEBUG);

  my $epochNow = time();

  # For start and stop epochs, if the value is '0', job processing will not 
  # occur.  This feature exists as an easy way to turn off the schedule.  To
  # turn the schedule back on, supply any non-numeric value for epoch start
  # or stop.
  my $epochStop  = &checkNextTime(
    'stop',
    $accessKey,
    $secretKey,
    $region,
    $instance->InstanceID,
    $instanceSchedule
  );

  my $epochStart = &checkNextTime(
    'start',
    $accessKey,
    $secretKey,
    $region,
    $instance->InstanceID,
    $instanceSchedule
  );

  if($DEBUG) {
    print 'EPOCH NOW: '   . $epochNow   . ' => ' . localtime($epochNow)   . "\n";
    print 'EPOCH START: ' . $epochStart . ' => ' . localtime($epochStart) . "\n";
    print 'EPOCH STOP: '  . $epochStop  . ' => ' . localtime($epochStop)  . "\n";
  }

  if($instance->State eq 'running') {
    next unless($epochStop);

    # Should this instance be stopped...
    if($epochStop < $epochNow) {
      # Stop instance...
      print localtime(time) . ' Stopping ' . $instance->InstanceName . "...\n";
      &stopInstance(
        $accessKey,
        $secretKey,
        $region,
        $instance->InstanceID,
        $instanceSchedule
      );
    }
  } elsif($instance->State eq 'stopped') {
    next unless($epochStart);

    # Should this instance be started...
    if($epochStart < $epochNow && $epochStop > $epochNow) {
      # Start instance...
      print localtime(time) . ' Starting ' . $instance->InstanceName . "...\n";
      &startInstance(
        $accessKey,
        $secretKey,
        $region,
        $instance->InstanceID,
        $instanceSchedule
      );
    }
  } else {
    print 'WARNING: Transitional State Detected' . "\n" if($DEBUG);
  }
}

print localtime(time) . ' [Scheduler] End Run...' .  "\n" if($DEBUG);

# Kill our pid file...
undef $ppObj;

exit 0;

sub checkInt {
  my ($value) = @_;
  return $value if($value =~ m/^[0-9]+/);
  return 0;
}

sub checkNextTime {
  my ($type, $accessKey, $secretKey, $region, $instanceID, $scheduleObj) = @_;
  my $value = $scheduleObj->NextStop;

  $value = $scheduleObj->NextStart if($type eq 'start');
  return $value if($value =~ m/^[0-9]+/);

  # If we have a non-numeric string, regenerate both next times...
  $scheduleObj->calculateNextTime('stop');
  $scheduleObj->calculateNextTime('start');

  print localtime(time) . " $instanceID Changing next $type time...\n";

  &updateTag(
    $accessKey,
    $secretKey,
    $region,
    $instanceID,
    $scheduleObj->serialize()
  );

  return 0;
}

sub getInstances {
  my ($accessKey, $secretKey, $region, $ids) = @_;
  my $instances = new StackIt::Collection::EC2::Instance();

  $instances->AWSAccessKeyId($accessKey);
  $instances->SecretKey($secretKey);
  $instances->Region($region);
  $instances->InstanceIDs($ids);

  $instances->populate();
  &printErrors($instances->Log->Errors);

  return $instances->Collection;
}

sub getScheduleByInstanceID {
  my ($schedules, $id) = @_;

  foreach my $schedule (@{$schedules}) {
    return $schedule if($schedule->InstanceID eq $id);
  }
}

sub getSchedules {
  my ($accessKey, $secretKey, $region) = @_;
  my $schedules = new StackIt::Collection::EC2::Schedule();

  $schedules->AWSAccessKeyId($accessKey);
  $schedules->SecretKey($secretKey);
  $schedules->Region($region);

  $schedules->populate();
  &printErrors($schedules->Log->Errors);

  return $schedules->Collection;
}

sub printErrors {
  my ($errors) = @_;

  if(@{$errors}) {
    foreach my $error (@{$errors}) {
      print $error . "\n";
    }

    exit 1;
  }
}

sub stopInstance {
  my ($accessKey, $secretKey, $region, $instanceID, $scheduleObj) = @_;
  my $request = new StackIt::AWS::EC2::Stop();

  $request->AWSAccessKeyId($accessKey);
  $request->SecretKey($secretKey);
  $request->Region($region);
  $request->InstanceId([$instanceID]);

  $request->post();
  &printErrors($request->Log->Errors);

  &updateTag(
    $accessKey,
    $secretKey,
    $region,
    $instanceID,
    $scheduleObj->serialize(0, 1)
  );
}

sub startInstance {
  my ($accessKey, $secretKey, $region, $instanceID, $scheduleObj) = @_;
  my $request = new StackIt::AWS::EC2::Start();

  $request->AWSAccessKeyId($accessKey);
  $request->SecretKey($secretKey);
  $request->Region($region);
  $request->InstanceId([$instanceID]);

  $request->post();
  &printErrors($request->Log->Errors);

  &updateTag(
    $accessKey,
    $secretKey,
    $region,
    $instanceID,
    $scheduleObj->serialize(1, 0)
  );
}

sub updateTag {
  my ($accessKey, $secretKey, $region, $instanceID, $scheduleStr) = @_;
  my $request = new StackIt::AWS::EC2::Tag::Create();

  $request->AWSAccessKeyId($accessKey);
  $request->SecretKey($secretKey);
  $request->Region($region);

  $request->ResourceId([ $instanceID ]);
  $request->addTag(
    {
      'Key'   => 'schedule',
      'Value' => $scheduleStr
    }
  );

  $request->post();
  &printErrors($request->Log->Errors);
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
  print "\t" . '--help|-h        Print this help message' . "\n";
  print "\t" . '--config|c       Configuration file'. "\n";
  print "\t" . '--access-key|-a  AWS access key' . "\n";
  print "\t" . '--secret-key|-s  AWS secret key' . "\n";
  print "\t" . '--region|-r      AWS region' . "\n";
  print "\t" . '--debug          Print debug messages' . "\n";
  print "\n";
  exit $exit_status;
}
