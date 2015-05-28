package StackIt::EC2::DNS;

use Moose;
use StackIt::Moose::Types;

extends 'StackIt::Object';

# String Properties
has 'InstanceID' => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'FQDN'       => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'RootZone'   => ( is => 'rw', isa => 'CleanStr', default => '' );

# Public Methods

# Private Methods

no Moose;

1;
