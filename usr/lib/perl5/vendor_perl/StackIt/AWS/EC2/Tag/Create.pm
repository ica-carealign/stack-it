package StackIt::AWS::EC2::Tag::Create;

use Moose;

extends 'StackIt::AWS::EC2';

# String Properties
has 'Action' => ( is => 'rw', isa => 'CleanStr', default => 'CreateTags' );

# List Properties
has 'ResourceId' => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );
has 'Tag'        => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );

has 'Properties' => (
  is      => 'ro',
  isa     => 'ArrayRef',
  default => sub {
    [
      'AWSAccessKeyId',
      'Action',
      'ResourceId',
      'Tag',
      'SignatureMethod',
      'SignatureVersion',
      'Timestamp',
      'Version'
    ]
  }
);

# Public Methods
sub addTag {
  my ($self, $tag) = @_;
  push @{$self->Tag}, $tag;
}

no Moose;

1;
