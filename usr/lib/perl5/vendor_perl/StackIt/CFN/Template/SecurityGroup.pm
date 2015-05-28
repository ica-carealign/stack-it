package StackIt::CFN::Template::SecurityGroup;

use Moose;

extends 'StackIt::CFN::Template';

# String Properties
has 'Description' => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'VpcID'       => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Subnet'      => ( is => 'rw', isa => 'CleanStr', default => '' );

has 'Template' => (
  is      => 'rw',
  isa     => 'CleanStr',
  default => 'security_group.tpl'
);

# List Properties
has 'Ports' => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );

# Public Methods

# Private Methods

no Moose;

1;
