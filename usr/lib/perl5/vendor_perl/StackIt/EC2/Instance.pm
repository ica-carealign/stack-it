package StackIt::EC2::Instance;

use Moose;
use Time::Local;
use Date::Parse;
use StackIt::Moose::Types;

extends 'StackIt::Object';

# String Properties
has 'InstanceName'       => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'InstanceID'         => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'ImageName'          => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'ImageID'            => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'HostName'           => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'PublicDNS'          => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'PrivateDNS'         => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'State'              => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'KeyName'            => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'LaunchIdx'          => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'ProductCodes'       => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'InstanceType'       => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Zone'               => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'KernelID'           => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'RAMDiskID'          => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Platform'           => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'MonitoringState'    => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'PublicIP'           => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'PrivateIP'          => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'VPCID'              => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'SubnetID'           => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'StorageType'        => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Lifecycle'          => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'SpotRequestID'      => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'InstanceLicense'    => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'ClusterGroup'       => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'VirtualizationType' => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Hypervisor'         => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'ClientToken'        => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'SecurityGroupID'    => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Tenancy'            => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'EBSOptimized'       => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'AmazonResourceName' => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'StackName'          => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Architecture'       => ( is => 'rw', isa => 'CleanStr', default => '' );

has 'LaunchTime' => (
  is      => 'rw',
  isa     => 'CleanStr',
  default => '',
  trigger => \&_convertUTC
);

# Integer Properties
has 'BuildStatus' => ( is => 'rw', isa => 'Int', default => 0 );

# Private Methods
sub _convertUTC {
  my ($self) = @_;

  if($self->LaunchTime =~ m/000(0|Z)$/) {
    $self->{'LaunchTime'} = localtime(str2time($self->LaunchTime));
  }
}
no Moose;

1;
