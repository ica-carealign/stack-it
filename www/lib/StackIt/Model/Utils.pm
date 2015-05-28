package StackIt::Model::Utils;

use Moose;

# Object Properties
has 'DBH' => ( is => 'rw', isa => 'DBI' );

# Private Methods
sub _convertCollectionToArray {
  my ($self, $collection) = @_;
  my $array = $collection->toArray();

  $self->_logMessages($collection);

  foreach my $obj (@{$collection->Collection}) {
    $self->_logMessages($obj);
  }

  return $array;
}

sub _convertCollectionToHash {
  my ($self, $collection) = @_;
  my $hash = $collection->toHash();

  $self->_logMessages($collection);

  foreach my $obj (@{$collection->Collection}) {
    $self->_logMessages($obj);
  }

  return $hash;
}

sub _logMessages {
  my ($self, $object) = @_;
  my $levelHandlerMap = {
    'Debug'    => 'debug',
    'Info'     => 'info',
    'Warnings' => 'warn',
    'Errors'   => 'error'
  };

  foreach my $level ('Debug', 'Info', 'Warnings', 'Errors') {
    my $handler = $levelHandlerMap->{$level};
    foreach my $message (@{$object->Log->$level}) {
      StackIt->log->$handler($message);
    }
  }
}

no Moose;

1;
