package StackIt::Model::DB::Schedule;

use Moose;

use StackIt::DB::Schedule;
use StackIt::DB::Collection::Schedule;

extends 'StackIt::Model::Utils';

# Public Methods
sub list {
  my ($self, $options) = @_;
  my ($schedules);

  $options->{'DBH'} = $self->DBH;
  $schedules = new StackIt::DB::Collection::Schedule($options);
  return $self->_convertCollectionToHash($schedules);
}

sub get {
  my ($self, $id) = @_;
  my $schedule = new StackIt::DB::Schedule('DBH' => $self->DBH);

  $schedule->ID($id) if($id);

  $self->_logMessages($schedule);

  return $schedule;
}

no Moose;

1;
