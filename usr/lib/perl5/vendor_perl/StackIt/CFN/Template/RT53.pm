package StackIt::CFN::Template::RT53;

use Moose;

extends 'StackIt::CFN::Template';

# String Properties
has 'FQDN'     => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Instance' => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Type'     => ( is => 'rw', isa => 'CleanStr', default => 'A' );
has 'Zone'     => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Resource' => ( is => 'rw', isa => 'Maybe[CleanStr]' );

has 'Template' => (
  is      => 'rw',
  isa     => 'CleanStr',
  default => 'rt53.tpl'
);

# Integer Properties
has 'TTL' => ( is => 'rw', isa => 'Int', default => 3600 );

# Public Methods

# Private Methods

no Moose;

1;
