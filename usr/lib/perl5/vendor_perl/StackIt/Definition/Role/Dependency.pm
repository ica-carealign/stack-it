package StackIt::Definition::Role::Dependency;

use Moose;
use StackIt::Moose::Types;

# String Propeties
has 'Role' => ( is => 'rw', isa => 'CleanStr', default => '' );

# Integer Properties
has 'Port' => ( is => 'rw', isa => 'Int', default => 0 );

no Moose;

1;
