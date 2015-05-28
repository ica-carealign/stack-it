package StackIt::DB::Schedule;

use Moose;

extends 'StackIt::DB', 'StackIt::EC2::Schedule';

# String Properties

# Integer Properties
has 'ID' => (
  is      => 'rw',
  isa     => 'Int',
  default => 0,
  trigger => sub { 
    my ($self) = @_;
    $self->_loadByID();
  }
);

# Boolean Properties
has 'Populated' => ( is => 'ro', isa => 'Bool', default => 0 );

# Public Methods

# Private Methods
sub _loadByID {
  my ($self) = @_;
  my ($sql, $sth);

  return 0 if($self->Populated);

  unless($self->ID) {
    $self->Log->error('Cannot select:  ID undefined');
    return 1;
  }

  $sql  = 'SELECT * FROM `schedule` WHERE `id` = ?';

  $sth = $self->DBH->prepare($sql);

  unless($sth) {
    $self->Log->error($self->DBH->errstr);
    return 1;
  }

  $sth->execute($self->ID);

  if($sth->errstr) {
    $self->Log->error($sth->errstr);
    return 1;
  }

  # Should only be one record because of the UNIQUE constraint...
  if($sth->rows) {
    my $record = $sth->fetchrow_hashref();

    $self->{'ID'}          = $record->{'id'};
    $self->{'Description'} = $record->{'description'};
    $self->{'StartTime'}   = $record->{'start_time'};
    $self->{'StopTime'}    = $record->{'stop_time'};
    $self->{'Weekends'}    = $record->{'weekends'};
  }

  $self->{'Populated'} = 1;
  $sth->finish() if($sth);
  return 0;
}

no Moose;

1;
