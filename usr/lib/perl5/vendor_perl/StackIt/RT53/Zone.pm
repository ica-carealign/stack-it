package StackIt::RT53::Zone;

use Moose;
use StackIt::Moose::Types;

extends 'StackIt::Object';

# String Properties
has 'ID'   => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Name' => ( is => 'rw', isa => 'CleanStr', default => '' );

# Integer Properties
has 'RRCount' => ( is => 'rw', isa => 'Int', default => 0 );

# Public Methods

# Private Methods

no Moose;

1;
