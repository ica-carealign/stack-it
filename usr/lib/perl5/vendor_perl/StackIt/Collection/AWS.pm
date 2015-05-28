package StackIt::Collection::AWS;

use Moose;
use StackIt::Moose::Types;

extends 'StackIt::Collection';

# String Properties
has 'Action'         => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'AWSAccessKeyId' => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'SecretKey'      => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Region'         => ( is => 'rw', isa => 'CleanStr', default => '' );

no Moose;

1;
