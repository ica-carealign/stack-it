package StackIt::Collection;

use Moose;
use StackIt::Moose::Types;
use StackIt::Log;

# List Properties
has 'Collection' => ( is => 'ro', isa => 'ArrayRef', default => sub { [] } );

# Log Object
has 'Log' => (
  is      => 'rw',
  isa     => 'Log',
  default => sub { return new StackIt::Log(); }
);

# Public Methods
sub addMember {
  my ($self, $member_obj) = @_;
  push @{$self->{Collection}}, $member_obj;
}

sub removeMember {
  my ($self) = @_;
  $self->Log->warning('removeMember() must be implemented in child object');
}

sub toArray {
  my ($self) = @_;
  my $records = [];

  foreach my $obj (@{$self->Collection}) {
    push @{$records}, $obj->toHash();
  }

  return $records;
}

sub toHash {
  my ($self, $reference) = @_;
  my ($record, $root);

  $root = $reference ? $reference : $self;

  foreach my $key (sort keys %{$root}) {
    next if($key eq 'DBH');

    # Security fix...
    next if($key eq 'AWSAccessKeyId');
    next if($key eq 'SecretKey');

    if($key eq 'Collection') {
      $record->{'Collection'} = [];

      foreach my $obj (@{$self->Collection}) {
        push @{$record->{'Collection'}}, $obj->toHash();
      }
    } else {
      if(blessed $root->$key) {
        $record->{$key} = $self->toHash($root->$key);
      } else {
        $record->{$key} = $root->$key;
      }
    }
  }

  return $record;
}

no Moose;

1;
