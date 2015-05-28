package StackIt::Model::DB::Environment;

use Moose;

use StackIt::DB::Collection::Environment;

extends 'StackIt::Model::Utils';

# Public Methods
sub list {
  my ($self, $options) = @_;
  my ($collection);

  $options->{'DBH'} = $self->DBH;
  $collection = new StackIt::DB::Collection::Environment($options);

  return $self->_convertCollectionToHash($collection);
}

no Moose;

1;
