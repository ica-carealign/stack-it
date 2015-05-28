package StackIt::AWS::EC2::Tag::List;

use Moose;

extends 'StackIt::AWS::EC2';

# String Properties
has 'Action' => ( is => 'rw', isa => 'CleanStr', default => 'DescribeTags' );

# List Properties
has 'Filter' => (
  is => 'rw',
  isa => 'ArrayRef',
  default => sub {
    [
      {
        'Name'    => 'resource-type',
        'Value.1' => 'instance'
      }
    ]
  }
);

has 'Properties' => (
  is      => 'ro',
  isa     => 'ArrayRef',
  default => sub {
    [
      'AWSAccessKeyId',
      'Action',
      'Filter',
      'SignatureMethod',
      'SignatureVersion',
      'Timestamp',
      'Version'
    ]
  }
);

# Public Methods
sub addFilter {
  my ($self, $filter) = @_;
  push @{$self->Filter}, $filter;
}

no Moose;

1;
