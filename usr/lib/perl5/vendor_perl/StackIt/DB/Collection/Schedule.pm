package StackIt::DB::Collection::Schedule;

use Moose;

use StackIt::DB::Schedule;

extends 'StackIt::Collection', 'StackIt::DB';

# String Properties

# Private Methods
sub BUILD {
  my ($self) = @_;
  my ($sql, $sth);

  $sql = 'SELECT `id` FROM `schedule`';

  $sth = $self->DBH->prepare($sql);

  unless($sth) {
    $self->Log->error($self->DBH->errstr);
    return 1;
  }

  $sth->execute();

  if($sth->errstr) {
    $self->Log->error($sth->errstr);
    return 1;
  } 

  while(my $record = $sth->fetchrow_hashref()) {
    my $scheduleObj = new StackIt::DB::Schedule( 'DBH' => $self->DBH );
    $scheduleObj->ID($record->{'id'});
    $self->addMember($scheduleObj);
  }

  $sth->finish() if($sth);
  return 0;
}

no Moose;

1;
