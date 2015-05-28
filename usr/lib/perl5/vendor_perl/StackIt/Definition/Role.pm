package StackIt::Definition::Role;

use Moose;
use StackIt::Moose::Types;

# String Properties
has 'Role'        => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Environment' => ( is => 'rw', isa => 'CleanStr', default => '' );

# List Properties
has 'Ports'        => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );
has 'Dependencies' => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );

# Public Methods
sub addPort {
  my ($self, $portObj) = @_;

  if(ref($portObj) ne 'StackIt::Definition::Role::Port') {
    print STDERR "Invalid port object!\n";
    return 1;
  }

  push @{$self->Ports}, $portObj;
  return 0;
}

sub addDependency {
  my ($self, $dependencyObj) = @_;

  if(ref($dependencyObj) ne 'StackIt::Definition::Role::Dependency') {
    print STDERR "Invalid dependency object!\n";
    return 1;
  }

  push @{$self->Dependencies}, $dependencyObj;
  return 0;
}

no Moose;

1;
