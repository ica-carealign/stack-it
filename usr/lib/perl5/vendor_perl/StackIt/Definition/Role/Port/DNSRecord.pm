package StackIt::Definition::Role::Port::DNSRecord;

use Moose;
use StackIt::Moose::Types;

# String Properties
has 'Type'     => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Name'     => ( is => 'rw', isa => 'CleanStr', default => '' );

# Integer Properties
has 'PortID' => ( is => 'rw', isa => 'Int', default => 0 );
has 'TTL'    => ( is => 'rw', isa => 'Maybe[Int]' );

no Moose;

1;
