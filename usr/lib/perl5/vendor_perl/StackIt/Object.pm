package StackIt::Object;

use Moose;
use StackIt::Moose::Types;
use StackIt::Log;

use Data::Dumper;

# Log Object
has 'Log' => (
  is      => 'rw',
  isa     => 'Log',
  default => sub { return new StackIt::Log(); }
);

# Public Methods
sub toHash {
  my ($self, $reference) = @_;
  my ($record, $root);

  $root = $reference ? $reference : $self;

  foreach my $key (sort keys %{$root}) {
    next if($key eq 'DBH');

    if(blessed $root->$key) {
      $record->{$key} = $self->toHash($root->$key);
    } else {
      $record->{$key} = $root->$key;
    }
  }

  return $record;
}

no Moose;

1;
