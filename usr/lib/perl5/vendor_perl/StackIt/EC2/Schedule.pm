package StackIt::EC2::Schedule;

use Moose;
use StackIt::Moose::Types;
use StackIt::Time;

extends 'StackIt::Object';

# String Properties
has 'InstanceID'  => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Description' => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'StartTime'   => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'StopTime'    => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'NextStart'   => ( is => 'rw', isa => 'CleanStr', default => '0' );
has 'NextStop'    => ( is => 'rw', isa => 'CleanStr', default => '0' );

# Boolean Properties
has 'Weekends' => ( is => 'rw', isa => 'Bool', default => 0 );

# Object Properties
has 'Time' => ( is => 'ro', isa => 'Object' );

# Public Methods
sub calculateNextTime {
  my ($self, $type) = @_;
  my $scheduledTime = $type eq 'start' ? $self->StartTime : $self->StopTime;
  my $scheduleEpochTime = 0;
  my $secondsInDay = 86400;

  $scheduleEpochTime = $self->Time->epochTime($scheduledTime);

  if($scheduleEpochTime < $self->Time->epochTime()) {
    if($self->Time->DayOfWeek == 5 && $self->Weekends == 0) {
      # If it is Friday and we do not run on weekends, fast forward 3 days...
      $scheduleEpochTime += $secondsInDay * 3;
    } elsif($self->Time->DayOfWeek == 6 && $self->Weekends == 0) {
      # If it is Saturday and we do not run on weekends, fast forward 2 days...
      $scheduleEpochTime += $secondsInDay * 2;
    } else {
      # Fast forward one day...
      $scheduleEpochTime += $secondsInDay;
    }
  }

  if($type eq 'start') {
    $self->NextStart($scheduleEpochTime);
  } else {
    $self->NextStop($scheduleEpochTime);
  }
}

sub serialize {
  my ($self, $newStart, $newStop) = @_;
  my $startTime = $self->StartTime;
  my $stopTime  = $self->StopTime;

  $self->calculateNextTime('start') if($newStart);
  $self->calculateNextTime('stop')  if($newStop);

  return join(
    '|',
    $self->Description,
    $self->StartTime,
    $self->StopTime,
    $self->Weekends,
    $self->NextStart,
    $self->NextStop
  );
}

# Private Methods
sub BUILD {
  my ($self) = @_;
  $self->{'Time'} = new StackIt::Time();
}

no Moose;

1;
