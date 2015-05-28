package StackIt::Model::DB::Port;

use Moose;

use StackIt::DB::Collection::Port;

extends 'StackIt::Model::Utils';

# Public Methods
sub list {
  my ($self, $options) = @_;
  my ($ports);

  $options->{'DBH'} = $self->DBH;
  $ports = new StackIt::DB::Collection::Port($options);
  return $self->_convertCollectionToHash($ports);
}

no Moose;

1;
