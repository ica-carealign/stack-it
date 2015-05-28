package StackIt::AWS::CFN::List;

use Moose;

extends 'StackIt::AWS::CFN';

# String Properties
has 'Action' => ( is => 'rw', isa => 'CleanStr', default => 'DescribeStacks' );

# List Properties
has 'Properties' => (
  is      => 'ro',
  isa     => 'ArrayRef',
  default => sub {
    [
      'AWSAccessKeyId',
      'Action',
      'SignatureMethod',
      'SignatureVersion',
      'Timestamp',
      'Version'
    ]
  }
);

no Moose;

1;
