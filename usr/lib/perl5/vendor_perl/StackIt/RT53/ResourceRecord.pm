package StackIt::RT53::ResourceRecord;

use Moose;
use StackIt::Moose::Types;

extends 'StackIt::Object';

# String Properties
has 'FQDN'  => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Type'  => ( is => 'rw', isa => 'CleanStr', default => '' );

# Integer Properties
has 'TTL' => ( is => 'rw', isa => 'Int', default => 3600 );

# List Properties
has 'Values' => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );

# Public Methods
sub addValue {
  my ($self, $value) = @_;
  push @{$self->Values}, $value;
}

# Private Methods

no Moose;

1;
