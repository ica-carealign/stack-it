package StackIt::CFN::Template::WaitHandler;

use Moose;

extends 'StackIt::CFN::Template';

# String Properties
has 'Template' => (
  is      => 'rw',
  isa     => 'CleanStr',
  default => 'wait_handler.tpl'
);

# Public Methods

# Private Methods

no Moose;

1;
