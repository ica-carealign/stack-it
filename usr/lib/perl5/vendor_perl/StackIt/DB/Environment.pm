package StackIt::DB::Environment;

use Moose;

extends 'StackIt::DB', 'StackIt::Object';

# String Properties
has 'Environment' => ( is => 'rw', isa => 'CleanStr', default => '' );

# Public Methods

# Private Methods

no Moose;

1;
