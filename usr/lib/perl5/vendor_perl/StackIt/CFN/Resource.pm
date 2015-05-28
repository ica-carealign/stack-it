package StackIt::CFN::Resource;

use Moose;
use StackIt::Moose::Types;

extends 'StackIt::Object';

# String Properties
has 'LogicalID'   => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'PhysicalID'  => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Type'        => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'LastUpdated' => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Status'      => ( is => 'rw', isa => 'CleanStr', default => '' );

no Moose;

1;
