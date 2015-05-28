package StackIt::CFN::Template::WaitCondition;

use Moose;

extends 'StackIt::CFN::Template';

# String Properties
has 'Instance'    => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'WaitHandler' => ( is => 'rw', isa => 'CleanStr', default => '' );

has 'Template' => (
  is      => 'rw',
  isa     => 'CleanStr',
  default => 'wait_condition.tpl'
);

# Integer Properties
has 'Count'   => ( is => 'rw', isa => 'Int', default => 1 );
has 'Timeout' => ( is => 'rw', isa => 'Int', default => 0 );

# Public Methods

# Private Methods

no Moose;

1;
