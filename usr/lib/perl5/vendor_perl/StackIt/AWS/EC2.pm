package StackIt::AWS::EC2;

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
  default => '2014-05-01'
);

# List Properties
has 'EndPoints' => (
  is      => 'rw',
  isa     => 'HashRef',
  default => sub {
    {
      'us-east-1' => 'ec2.us-east-1.amazonaws.com',
      'us-west-2' => 'ec2.us-west-2.amazonaws.com'
    }
  }
);

# Public Methods

# Private Methods

no Moose;

1;
