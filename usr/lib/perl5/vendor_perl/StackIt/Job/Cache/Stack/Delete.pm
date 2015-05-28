package StackIt::Job::Cache::Stack::Delete;

use Moose;

use StackIt::EC2::HostName;
use StackIt::Collection::CFN::Resource;
use StackIt::Collection::EC2::Instance;
use StackIt::Moose::Types;
use StackIt::System::Call::Puppet::Clean;
use StackIt::AWS::CFN::Delete;
use StackIt::DB::Config;
use StackIt::DB::PrivateIP;
use StackIt::DB::Collection::Instance;

# String Properties
has 'CacheServer' => ( is => 'rw', isa => 'Str', default => 'localhost' );

has 'AWSAccessKeyId' => ( is => 'rw', isa => 'CleanStr', default => '', required => 1);
has 'SecretKey'      => ( is => 'rw', isa => 'CleanStr', default => '', required => 1);
has 'StackName'      => ( is => 'rw', isa => 'CleanStr', default => '', required => 1);
has 'Region'         => ( is => 'rw', isa => 'CleanStr', default => '', required => 1);
has 'RootZone'       => ( is => 'rw', isa => 'CleanStr', default => '', required => 1);

# Integer Properties
has 'CachePort'           => ( is => 'rw', isa => 'Int', default => 11211 ); 
has 'CacheTTL'            => ( is => 'rw', isa => 'Int', default => 0     );

# Boolean Properties
has 'CleanPuppet'    => ( is => 'rw', isa => 'Bool', default => 0 );

# Object Properties
has 'DBH' => ( is => 'rw', isa => 'Object' );

# List Properties
has 'LogLevels' => ( is => 'rw', isa => 'ArrayRef', default => sub { [ 'Errors' ] } );

# Private Methods
sub BUILD {
  my ($self) = @_;

  # Create database handle...
  $self->_dbConnect();

  # Get instance id's for the stack from AWS...
  my $instance_ids = $self->_getInstanceIDs();

  # Get instance details from AWS...
  my $AWSInstances = $self->_getInstanceDataFromAWS($instance_ids);

  # Get instance records from StackIt...
  my $DBInstances = $self->_getInstanceDataFromDB();

  # Stop processing if we do not have the expected data...
  return 1 unless(@{$instance_ids});
  return 1 unless(@{$AWSInstances});
  return 1 unless(@{$DBInstances});
  
  my $puppet_hosts    = [];

  foreach my $instance (@{$AWSInstances}) {
    my $hostname = $self->_getHostName($instance->{'InstanceName'});

    next unless($hostname);
    push @{$puppet_hosts}, $hostname;

    # Delete instance records and reset private_ip records...
    foreach my $DBInstance (@{$DBInstances}) {
      if($DBInstance->Instance eq $instance->InstanceName) {
        $self->_resetPrivateIP($DBInstance->PrivateIPID);

        # Delete instance record...
        $DBInstance->delete();
        $DBInstance->Log->print($self->LogLevels);
      }
    }
  }

  # Clean server references from puppet...
  if($self->CleanPuppet && @{$puppet_hosts}) {
    $self->_removeInstanceFromPuppet($puppet_hosts);
  }

  # Delete stack...
  $self->_removeStackFromAWS();

  $self->DBH->disconnect();

  print __PACKAGE__ . ' job run complete' . "\n";
  return 0;
}

sub _dbConnect {
  my ($self) = @_;
  my $dbh = StackIt::DB::Config->new->connect;

  local $dbh->{'AutoCommit'} = 1;
  local $dbh->{'RaiseError'} = 1;

  $self->DBH($dbh);
}

sub _getInstanceIDs {
  my ($self) = @_;
  my $resources = new StackIt::Collection::CFN::Resource();
  my $instance_ids = [];

  $resources->StackName($self->StackName);
  $resources->AWSAccessKeyId($self->AWSAccessKeyId);
  $resources->SecretKey($self->SecretKey);
  $resources->Region($self->Region);

  $resources->populate();

  $resources->Log->print($self->LogLevels);
  return undef if(@{$resources->Log->Errors});

  # TODO:  Collections probably need a filter feature...
  foreach my $resource (@{$resources->Collection}) {
    if($resource->Type eq 'AWS::EC2::Instance') {
      push @{$instance_ids}, $resource->PhysicalID;
    }
  }

  return $instance_ids;
}

sub _getInstanceDataFromAWS {
  my ($self, $ids) = @_;
  my $instances = new StackIt::Collection::EC2::Instance();

  $instances->InstanceIDs($ids);
  $instances->StackName($self->StackName);
  $instances->AWSAccessKeyId($self->AWSAccessKeyId);
  $instances->SecretKey($self->SecretKey);
  $instances->Region($self->Region);
  $instances->RootZone($self->RootZone);

  $instances->populate();

  $instances->Log->print($self->LogLevels);

  return undef if(@{$instances->Log->Errors});
  return $instances->Collection;
}

sub _getInstanceDataFromDB {
  my ($self) = @_;
  my $instances = new StackIt::DB::Collection::Instance(
    'DBH'       => $self->DBH,
    'StackName' => $self->StackName
  );

  $instances->Log->print($self->LogLevels);
  return undef if(@{$instances->Log->Errors});
  return $instances->Collection;
}

sub _getHostName {
  my ($self, $instanceName) = @_;
  my $hostname = new StackIt::EC2::HostName();

  $hostname->InstanceName($instanceName);
  $hostname->RootZone($self->RootZone);
  $hostname->StackName($self->StackName);

  return $hostname->FQDN;
}

sub _removeInstanceFromPuppet {
  my ($self, $hosts) = @_;
  my $call = new StackIt::System::Call::Puppet::Clean();

  $call->Hosts($hosts);
  $call->run();

  $call->Log->print($self->LogLevels);
  return $call->ExitCode;
}

sub _removeStackFromAWS {
  my ($self) = @_;
  my $request = new StackIt::AWS::CFN::Delete();

  $request->AWSAccessKeyId($self->AWSAccessKeyId);
  $request->SecretKey($self->SecretKey);
  $request->Region($self->Region);
  $request->StackName($self->StackName);

  $request->post();

  $request->Log->print($self->LogLevels);
  return $request->StatusCode == 200 ? 0 : $request->StatusCode;
}

sub _resetPrivateIP {
  my ($self, $id) = @_;
  my $ipObj = new StackIt::DB::PrivateIP('DBH' => $self->DBH);

  $ipObj->ID($id);
  $ipObj->Processing(0);
  $ipObj->Active(0);

  $ipObj->update();

  $ipObj->Log->print($self->LogLevels);
  return @{$ipObj->Log->Errors} ? 1 : 0;
}

no Moose;

1;
