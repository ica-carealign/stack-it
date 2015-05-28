package StackIt::Model::DB::Role;

use Moose;

use StackIt::DB::Role;
use StackIt::DB::Collection::Role;

extends 'StackIt::Model::Utils';

# Public Methods
sub list {
  my ($self, $options) = @_;
  my ($roles);

  $options->{'DBH'} = $self->DBH;
  $roles = new StackIt::DB::Collection::Role($options);
  return $self->_convertCollectionToHash($roles);
}

sub getID {
  my ($self, $options) = @_;
  my $id = 1;

  if($options->{'Role'} && $options->{'Environment'}) {
    $options->{'DBH'} = $self->DBH;

    my $role = new StackIt::DB::Role($options);
    $role->loadByRoleEnvironment();

    $self->_logMessages($role);
    $id = $role->ID if($role->ID);
  }

  return $id;
}

no Moose;

1;
