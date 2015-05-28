package StackIt::AWS::CFN::Resource;

use Moose;
use StackIt::Moose::Types;

extends 'StackIt::AWS::CFN';

# String Properties
has 'StackName' => ( is => 'rw', isa => 'AlphaNumStr', default => '' );

has 'Action' => (
  is      => 'rw',
  isa     => 'CleanStr',
  default => 'DescribeStackResources'
);

# List Properties
has 'Properties' => (
  is      => 'ro',
  isa     => 'ArrayRef',
  default => sub {
    [
      'AWSAccessKeyId',
      'Action',
      'StackName',
      'SignatureMethod',
      'SignatureVersion',
      'Timestamp',
      'Version'
    ]
  }
);

no Moose;

1;
