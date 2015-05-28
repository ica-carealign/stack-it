package StackIt::AWS::EC2::Stop;

use Moose;

extends 'StackIt::AWS::EC2';

# String Properties
has 'Action' => ( is => 'rw', isa => 'CleanStr', default => 'StopInstances' );

# List Properties
has 'InstanceId' => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );

has 'Properties' => (
  is      => 'ro',
  isa     => 'ArrayRef',
  default => sub {
    [
      'AWSAccessKeyId',
      'Action',
      'InstanceId',
      'SignatureMethod',
      'SignatureVersion',
      'Timestamp',
      'Version'
    ]
  }
);

no Moose;

1;
