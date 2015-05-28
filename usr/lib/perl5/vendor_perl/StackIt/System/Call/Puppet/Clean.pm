package StackIt::System::Call::Puppet::Clean;

use Moose;

extends 'StackIt::System::Call::Puppet';

# List Properties
has 'Hosts' => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );

# Public Methods
sub run {
  my ($self) = @_;
  my $command = '';

  return 0 unless(@{$self->Hosts});

  $command = 'sudo /usr/share/ica/puppet/bin/clean_puppet.sh ';

  foreach my $host (@{$self->Hosts}) {
    $command .= $host . ' ';
  }

  $command .= '2>&1';

  $self->Command($command);
  $self->GetOutput(1);

  $self->execute();
  return 1;
}

no Moose;

1;
