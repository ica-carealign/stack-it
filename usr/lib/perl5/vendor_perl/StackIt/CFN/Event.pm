package StackIt::CFN::Event;

use Moose;
use Time::Local;
use Date::Parse;

use StackIt::Moose::Types;

extends 'StackIt::Object';

# String Properties
has 'LogicalID' => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Reason'    => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'StackName' => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Status'    => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Type'      => ( is => 'rw', isa => 'CleanStr', default => '' );

has 'Timestamp'  => (
  is      => 'rw',
  isa     => 'CleanStr',
  default => '',
  trigger => \&_convertUTC
);

# Public Methods

# Private Methods
sub _convertUTC {
  my ($self) = @_;

  if($self->Timestamp =~ m/Z$/) {
    $self->{'Timestamp'} = localtime(str2time($self->Timestamp));
  }
}

no Moose;

1;
