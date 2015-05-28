package StackIt::Time;

use Moose;
use Time::Local;

# Integer Properties
has 'Hour'       => ( is => 'ro', isa => 'Int', default => 0 );
has 'Minute'     => ( is => 'ro', isa => 'Int', default => 0 );
has 'Second'     => ( is => 'ro', isa => 'Int', default => 0 );
has 'Month'      => ( is => 'ro', isa => 'Int', default => 0 );
has 'DayOfMonth' => ( is => 'ro', isa => 'Int', default => 0 );
has 'Year'       => ( is => 'ro', isa => 'Int', default => 0 );
has 'DayOfWeek'  => ( is => 'ro', isa => 'Int', default => 0 );
has 'DayOfYear'  => ( is => 'ro', isa => 'Int', default => 0 );

# Boolean Properties
has 'DST' => ( is => 'ro', isa => 'Bool', default => 0 );

# Public Methods
sub epochTime {
  my ($self, $scheduledTime) = @_;
  my $epochTime = 0;

  if($scheduledTime) {
    my ($s_hour, $s_minute, $s_second) = split(':', $scheduledTime);

    $epochTime = timelocal(
      $s_second,
      $s_minute,
      $s_hour,
      $self->DayOfMonth,
      $self->Month,
      $self->Year
    );
  } else {
    $epochTime = time();
  }

  return $epochTime;
}

sub isWeekend {
  my ($self) = @_;
  return 2 if($self->DayOfWeek == 6);
  return 1 if($self->DayOfWeek == 0);
  return 0;
}

# Private Methods
sub BUILD {
  my ($self) = @_;
  $self->_now();
}

sub _now {
  my ($self) = @_;
  my ( $sec,
       $min,
       $hour,
       $mday,
       $mon,
       $year,
       $wday,
       $yday,
       $dst   ) = localtime(time);

  $self->{'Hour'} = $hour;
  $self->{'Minute'} = $min;
  $self->{'Second'} = $sec;
  $self->{'Month'} = $mon;
  $self->{'DayOfMonth'} = $mday;
  $self->{'Year'} = $year + 1900;
  $self->{'DayOfWeek'} = $wday;
  $self->{'DayOfYear'} = $yday;
  $self->{'DST'} = $dst;
}

no Moose;

1;
