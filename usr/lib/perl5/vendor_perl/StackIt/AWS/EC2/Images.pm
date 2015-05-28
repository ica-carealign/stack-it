package StackIt::AWS::EC2::Images;

use Moose;

extends 'StackIt::AWS::EC2';

# String Properties
has 'Action' => ( is => 'rw', isa => 'CleanStr', default => 'DescribeImages' );

# List Properties
has 'ImageId' => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );

has 'Properties' => (
  is      => 'ro',
  isa     => 'ArrayRef',
  default => sub {
    [
      'AWSAccessKeyId',
      'Action',
      'ImageId',
      'SignatureMethod',
      'SignatureVersion',
      'Timestamp',
      'Version'
    ]
  }
);

no Moose;

1;
