package StackIt::Collection::EC2::Instance;

use Moose;
use Data::Dumper;

use StackIt::Moose::Types;
use StackIt::EC2::Instance;
use StackIt::EC2::HostName;
use StackIt::AWS::EC2::Instances;
use StackIt::AWS::EC2::Images;

extends 'StackIt::Collection::AWS';

# String Properties
has 'StackName'  => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'RootZone'   => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'PowerState' => ( is => 'rw', isa => 'CleanStr', default => '' ); 

# List Properties
has 'InstanceIDs'  => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );
has 'TmpInstances' => ( is => 'rw', isa => 'HashRef', default => sub { {} } );

# Private Methods
sub populate {
  my ($self) = @_;
  my $logs = { 'Errors' => 'error' };

  my $request = new StackIt::AWS::EC2::Instances();

  $request->AWSAccessKeyId($self->AWSAccessKeyId);
  $request->SecretKey($self->SecretKey);
  $request->Region($self->Region);
  $request->InstanceId($self->InstanceIDs);

  $request->post();

  foreach my $level (keys %{$logs}) {
    if(@{$request->Log->$level}) {
      foreach my $message (@{$request->Log->$level}) {
        my $method = $logs->{$level};
        $self->Log->$method($message);
      }
    }
  }

  $self->Log->debug('QUERY:  ' . $request->Query);
  $self->Log->debug('CONTENT:  ' . $request->Content);
  $self->Log->debug('OUTPUT:  ' . Dumper($request->Output));

  my $result = $request->Output->{'reservationSet'}->{'item'};

  foreach my $reservation (@{$result}) {
    foreach my $data (@{$reservation->{'instancesSet'}->{'item'}}) {
      my $instanceID = $data->{'instanceId'};
      my $imageID = $data->{'imageId'};

      $self->_checkTmpObjects($instanceID);

      my $instance = $self->TmpInstances->{$instanceID};

      $instance->InstanceID(&_checkValue($data->{'instanceId'}));
      $instance->ImageID(&_checkValue($data->{'imageId'}));
      $instance->PublicDNS(&_checkValue($data->{'dnsName'}));
      $instance->PrivateDNS(&_checkValue($data->{'privateDnsName'}));
      $instance->State(&_checkValue($data->{'instanceState'}->{'name'}));
      $instance->KeyName(&_checkValue($data->{'keyName'}));
      $instance->LaunchIdx(&_checkValue($data->{'amiLaunchIndex'}));
      $instance->InstanceType(&_checkValue($data->{'instanceType'}));
      $instance->LaunchTime(&_checkValue($data->{'launchTime'}));
      $instance->Zone(&_checkValue($data->{'placement'}->{'availabilityZone'}));
      $instance->KernelID(&_checkValue($data->{'kernelId'}));
      $instance->Platform(&_checkValue($data->{'platform'}));
      $instance->MonitoringState(&_checkValue($data->{'monitoring'}->{'state'}));
      $instance->PublicIP(&_checkValue($data->{'ipAddress'}));
      $instance->PrivateIP(&_checkValue($data->{'privateIpAddress'}));
      $instance->VPCID(&_checkValue($data->{'vpcId'}));
      $instance->SubnetID(&_checkValue($data->{'subnetId'}));
      $instance->StorageType(&_checkValue($data->{'rootDeviceType'}));
      $instance->VirtualizationType(&_checkValue($data->{'virtualizationType'}));
      $instance->Hypervisor(&_checkValue($data->{'hypervisor'}));
      $instance->ClientToken(&_checkValue($data->{'clientToken'}));
      $instance->Tenancy(&_checkValue($data->{'placement'}->{'tenancy'}));
      $instance->EBSOptimized(&_checkValue($data->{'ebsOptimized'}));
      $instance->Architecture(&_checkValue($data->{'architecture'}));

      $instance->StackName($self->StackName);

      # Get image name...
      if($imageID ne '') {
        $instance->ImageName($self->_getImageName($imageID));
      }

      # Get associated security groups...
      my $securityGroups = [];

      foreach my $group (@{$data->{'groupSet'}->{'item'}}) {
        push @{$securityGroups}, $group->{'groupId'};
      }

      $instance->SecurityGroupID(join(', ', @{$securityGroups}));

      # Get instance name...
      foreach my $tag (@{$data->{'tagSet'}->{'item'}}) {
        if($tag->{'key'} eq 'Name') {
          $instance->InstanceName($tag->{'value'});
          last;
        }
      }

      # Infer hostname...
      my $hostname = new StackIt::EC2::HostName();

      $hostname->InstanceName($instance->InstanceName);
      $hostname->RootZone($self->RootZone);
      $hostname->StackName($self->StackName);

      $instance->HostName($hostname->FQDN);

      # Track the stack's power state...
      $self->_checkState($instance->State);
    }
  }

  foreach my $instanceID (keys %{$self->TmpInstances}) {
    $self->addMember($self->TmpInstances->{$instanceID});
  }

  # Cleanup...
  $self->TmpInstances({});
}

sub _checkTmpObjects {
  my ($self, $instanceID) = @_;
  return if(exists $self->TmpInstances->{$instanceID});
  $self->TmpInstances->{$instanceID} = new StackIt::EC2::Instance();
}

sub _getImageName {
  my ($self, $imageID) = @_;
  my $logs = { 'Errors' => 'error' };

  unless($imageID) {
    $self->Log->warning('Skipping requrest:  missing ImageID');
    return '';
  }

  my $request = new StackIt::AWS::EC2::Images();

  $request->AWSAccessKeyId($self->AWSAccessKeyId);
  $request->SecretKey($self->SecretKey);
  $request->Region($self->Region);
  $request->ImageId([$imageID]);

  $request->post();

  foreach my $level (keys %{$logs}) {
    if(@{$request->Log->$level}) {
      foreach my $message (@{$request->Log->$level}) {
        my $method = $logs->{$level};
        $self->Log->$method($message);
      }
    }
  }

  $self->Log->debug($request->Query);
  $self->Log->debug($request->Content);

  my $result = $request->Output->{'imagesSet'}->{'item'};

  if($result && @{$result} != 1) {
    $self->Log->warning('Unexpected number of records returned');
  }

  return exists ${$result}[0]->{'name'} ? ${$result}[0]->{'name'} : '';
}

sub _checkValue {
  my ($value) = @_;
  return $value ? $value : '';
}

sub _checkState {
  my ($self, $state) = @_;

  return 0 if($self->PowerState eq 'mixed');

  if($self->PowerState eq '') {
    $self->PowerState($state);
  } elsif($self->PowerState ne $state) {
    $self->PowerState('mixed');
  }

  return 0;
}

no Moose;

1;
