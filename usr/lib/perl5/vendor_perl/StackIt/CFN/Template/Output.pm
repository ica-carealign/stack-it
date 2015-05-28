package StackIt::CFN::Template::Output;

use Moose;

extends 'StackIt::CFN::Template';

# String Properties
has 'Template' => (
  is      => 'rw',
  isa     => 'CleanStr',
  default => 'output.tpl'
);

# Public Methods

# Private Methods

no Moose;

1;
