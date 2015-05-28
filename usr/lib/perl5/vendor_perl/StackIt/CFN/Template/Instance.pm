package StackIt::CFN::Template::Instance;

use Moose;

extends 'StackIt::CFN::Template';

# Constants
use constant linux_template   => 'linux_instance.tpl';
use constant windows_template => 'windows_instance.tpl';

# String Properties
has 'ImageID'          => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'KeyName'          => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Role'             => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Version'          => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Environment'      => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'ArtifactServer'   => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'PuppetMaster'     => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'SubnetID'         => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'InstanceType'     => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'SecurityGroupID'  => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'SecurityGroupRef' => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'WaitHandler'      => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'PrivateIP'        => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'HostName'         => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Domain'           => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'InstanceName'     => ( is => 'rw', isa => 'CleanStr', default => '' );

has 'VolumeType'   => ( is => 'rw', isa => 'CleanStr', default => 'gp2'       );
has 'VolumeDevice' => ( is => 'rw', isa => 'CleanStr', default => '/dev/sda1' );

# Integer Properties
has 'VolumeSize' => ( is => 'rw', isa => 'Int', default => 0 );

# Boolean Properties
has 'SkipPuppet' => ( is => 'rw', isa => 'Bool', default => 0 );

# List Properties
has 'Tags' => ( is => 'rw', isa => 'HashRef', default => sub { {} } );

# Public Methods
sub isLinux {
  my ($self, $bool) = @_;

  if(defined($bool)) {
    if($bool) {
      $self->Template(linux_template);
    } else {
      $self->Template(windows_template);
    }
  } else {
    return ($self->Template eq linux_template) ? 1 : 0;
  }
}

# Private Methods

no Moose;

1;
