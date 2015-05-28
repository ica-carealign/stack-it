package StackIt::CFN::Stack;

use Moose;
use Time::Local;
use Date::Parse;

use StackIt::Moose::Types;

extends 'StackIt::Object';

# String Properties
has 'Description' => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Output'      => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'StackName'   => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Status'      => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'BuildStatus' => ( is => 'rw', isa => 'CleanStr', default => '' );

has 'CreateTime'  => (
  is      => 'rw',
  isa     => 'CleanStr',
  default => '',
  trigger => \&_convertUTC
);

has 'State' => (
  is      => 'ro',
  isa     => 'CleanStr',
  default => 'transitional'
);

# Integer Properties
has 'UpCount'     => ( is => 'ro', isa => 'Int', default => 0 );
has 'DownCount'   => ( is => 'ro', isa => 'Int', default => 0 );
has 'TransCount'  => ( is => 'ro', isa => 'Int', default => 0 );

# Public Methods

# Private Methods
sub _convertUTC {
  my ($self) = @_;

  if($self->CreateTime =~ m/Z$/) {
    $self->{'CreateTime'} = localtime(str2time($self->CreateTime));
  }
}

no Moose;

1;
