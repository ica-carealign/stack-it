package StackIt::AWS::CFN;

use Moose;
use StackIt::Moose::Types;

extends 'StackIt::AWS';

# String Properties
has 'Region' => (
  is      => 'rw',
  isa     => 'CleanStr',
  default => '',
  trigger => \&StackIt::AWS::_setBaseURLbyRegion
);

has 'Version' => (
  is      => 'rw',
  isa     => 'CleanStr',
  default => '2010-05-15'
);

# List Properties
has 'EndPoints' => (
  is      => 'rw',
  isa     => 'HashRef',
  default => sub {
    {
      'us-east-1' => 'cloudformation.us-east-1.amazonaws.com',
      'us-west-2' => 'cloudformation.us-west-2.amazonaws.com',
    }
  }
);

# Public Methods

# Private Methods

no Moose;

1;
