#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use Proc::Pidfile;
use Getopt::Long;
use Config::Simple;

use StackIt::Collection::EC2::DNS;
use StackIt::Collection::RT53::Zone;
use StackIt::Collection::EC2::Instance;
use StackIt::Collection::RT53::ResourceRecord;
use StackIt::AWS::RT53::ResourceRecord::Change;

my ($help, $configFile, $accessKey, $secretKey, $region);
my $zones = {};

my $templatePath = '/usr/share/stack-it/templates';

my $DEBUG = 0;

my $result = GetOptions(
  'help|h'         => \$help,
  'config|c=s'     => \$configFile,
  'access-key|a=s' => \$accessKey,
  'secret-key|s=s' => \$secretKey,
  'region|r=s'     => \$region,
  'debug|d'        => \$DEBUG
);

&usage(0) if($help);

if($configFile && -f $configFile) {
  my $config = new Config::Simple($configFile);

  $accessKey    = $config->param('AccessKey');
  $secretKey    = $config->param('SecretKey');
  $region       = $config->param('Region');
  $templatePath = $config->param('TemplatePath');
} else {
  &usage(1, 'Cannot access ' . $configFile);
}

&usage(1, 'access-key is required') unless($accessKey);
&usage(1, 'secret-key is required') unless($secretKey);
&usage(1, 'region is required')     unless($region);

# If the pidfile already exists, this will exit silently...
my $ppObj = new Proc::Pidfile(silent => 1);

print localtime(time) . ' [DNS Updater] Start Run...' .  "\n" if($DEBUG);

# Get dns tags...
my $dnsTags = &getDNSTags($accessKey, $secretKey, $region);

print 'TAGS: ' . Dumper($dnsTags) . "\n" if($DEBUG);

foreach my $tag (@{$dnsTags}) {
  my ($resourceRecords);

  # Get zone id from $rootZone...
  my $zoneID = &getZoneID($accessKey, $secretKey, $tag->RootZone);

  print 'ZONE ID: ' . $zoneID . "\n" if($DEBUG);

  next unless($zoneID);

  # Pull resource records for the zone...
  unless(exists $zones->{'zoneID'}) {
    $zones->{'zoneID'} = &getResourceRecords($accessKey, $secretKey, $zoneID);
  }

  $resourceRecords = $zones->{'zoneID'};

  print 'RESOURCE RECORDS: ' . Dumper($resourceRecords) . "\n" if($DEBUG);

  # Get instance data...
  my $instance = &getInstances(
    $accessKey,
    $secretKey,
    $region,
    [ $tag->InstanceID ]
  )->[0];

  print 'InstanceID: ' . $instance->InstanceID . "\n" if($DEBUG);

  next unless($instance->State eq 'running');

  # Grab 'A' record using fqdn...
  my $aRecord = $resourceRecords->getARecordByFQDN($tag->FQDN);

  print 'ARECORD: ' . Dumper($aRecord) . "\n" if($DEBUG);

  # Check if 'A' record matches the instance's public ip...
  if($aRecord) {
    unless(&aRecordCheck($aRecord, $instance->PublicIP)) {
      # Update record...
      print localtime(time) . ' Setting ' . $tag->FQDN . ' to ' . $instance->PublicIP . "\n";

      &updateResourceRecord(
        $accessKey,
        $secretKey,
        $zoneID,
        $tag->FQDN,
        $instance->PublicIP,
        $templatePath
      );
    }
  }
}

print localtime(time) . ' [DNS Updater] End Run...' .  "\n" if($DEBUG);

# Kill our pid file...
undef $ppObj;

exit 0;

sub aRecordCheck {
  my ($record, $ip) = @_;
  return 1 if($record->Values->[0] eq $ip);
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

sub getDNSTags {
  my ($accessKey, $secretKey, $region) = @_;
  my $tags = new StackIt::Collection::EC2::DNS();

  $tags->AWSAccessKeyId($accessKey);
  $tags->SecretKey($secretKey);
  $tags->Region($region);

  $tags->populate();
  &printErrors($tags->Log->Errors);

  return $tags->Collection;
}

sub getResourceRecords {
  my ($accessKey, $secretKey, $zoneID) = @_;
  my $resourceRecords = new StackIt::Collection::RT53::ResourceRecord();

  $resourceRecords->AWSAccessKeyId($accessKey);
  $resourceRecords->SecretKey($secretKey);
  $resourceRecords->ZoneID($zoneID);

  $resourceRecords->populate();
  &printErrors($resourceRecords->Log->Errors);

  return $resourceRecords;
}

sub getZoneID {
  my ($accessKey, $secretKey, $domain) = @_;
  my $zones = new StackIt::Collection::RT53::Zone();

  $zones->AWSAccessKeyId($accessKey);
  $zones->SecretKey($secretKey);

  $zones->populate();

  return $zones->getZoneIDbyName($domain) || '';
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

sub updateResourceRecord {
  my ( $accessKey,
       $secretKey,
       $zoneID,
       $fqdn,
       $ip,
       $templatePath ) = @_;

  my $request = new StackIt::AWS::RT53::ResourceRecord::Change();

  $request->AccessKey($accessKey);
  $request->SecretKey($secretKey);
  $request->ZoneID($zoneID);
  $request->FQDN($fqdn);
  $request->IP($ip);
  $request->TemplatePath($templatePath);

  $request->set();
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
