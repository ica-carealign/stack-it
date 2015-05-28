package StackIt::DB::Stack::Role;

use Moose;

use StackIt::DB::Collection::Port;
use StackIt::DB::Collection::Dependency;

extends 'StackIt::DB::Role';

# Method Modifiers
after '_loadByID' => \&_loadPortsAndDependencies;

# List Properties
has 'Ports'        => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );
has 'Dependencies' => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );

# Public Methods
sub addPort {
  my ($self, $portObj) = @_;

  if(ref($portObj) ne 'StackIt::DB::Port') {
    $self->Log->error('Invalid port object!');
    return 1;
  }

  push @{$self->Ports}, $portObj;
  return 0;
}

sub addDependency {
  my ($self, $dependencyObj) = @_;

  if(ref($dependencyObj) ne 'StackIt::DB::Dependency') {
    $self->Log->error('Invalid dependency object!');
    return 1;
  }

  push @{$self->Dependencies}, $dependencyObj;
  return 0;
}

sub save {
  my ($self) = @_;
  
  if($self->ID) {
    $self->Log->error('Role already exists');
    return 1;
  }

  $self->doTransaction(sub {
    $self->upsert();
    $self->expungeRelatedObjects();

    foreach my $port (@{$self->Ports}) {
      $port->RoleID($self->ID);
      $port->insert();
    }

    foreach my $dependency (@{$self->Dependencies}) {
      $dependency->RoleID($self->ID);
      $dependency->insert();
    }
  });

  return 0;
}

# Private Methods
sub _loadPortsAndDependencies {
  my ($self) = @_;
  my $portCollection = new StackIt::DB::Collection::Port(
    'DBH'    => $self->DBH,
    'RoleID' => $self->ID
  );

  foreach my $portObj (@{$portCollection->Collection}) {
    $self->addPort($portObj);
  }

  my $dependencyCollection = new StackIt::DB::Collection::Dependency(
    'DBH'    => $self->DBH,
    'RoleID' => $self->ID
  );

  foreach my $dependencyObj (@{$dependencyCollection->Collection}) {
    $self->addDependency($dependencyObj);
  }
}

no Moose;

1;
