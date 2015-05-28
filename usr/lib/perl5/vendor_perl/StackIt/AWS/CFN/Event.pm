package StackIt::AWS::CFN::Event;

use Moose;

extends 'StackIt::AWS::CFN';

# String Properties
has 'Action'    => ( is => 'rw', isa => 'CleanStr', default => 'DescribeStackEvents' );
has 'StackName' => ( is => 'rw', isa => 'AlphaNumStr', default => '' );

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
