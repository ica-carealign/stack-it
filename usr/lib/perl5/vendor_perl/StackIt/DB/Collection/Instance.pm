package StackIt::DB::Collection::Instance;

use Moose;
use Time::Local;

use StackIt::DB::Instance;
use StackIt::Time;

extends 'StackIt::Collection', 'StackIt::DB';

# String Properties
has 'StackName' => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Status'    => ( is => 'rw', isa => 'CleanStr', default => 'pending' );

# Integer Properties
has 'BuildStatus'   => ( is => 'ro', isa => 'Int', default => 0 );
has 'StatusTimeOut' => ( is => 'ro', isa => 'Int', default => 0 );

# Private Methods
sub BUILD {
  my ($self) = @_;
  my ($sql, $sth, @parameters);
  my $records = 0;

  if($self->StackName) {
    $sql = 'SELECT `id` FROM `instance` WHERE `stack` = ?';
    push @parameters, $self->StackName;
  } else {
    $sql = 'SELECT `id` FROM `instance`';
  }

  $sth = $self->DBH->prepare($sql);

  unless($sth) {
    $self->Log->error($self->DBH->errstr);
    return 1;
  }

  $sth->execute(@parameters);

  if($sth->errstr) {
    $self->Log->error($sth->errstr);
    return 1;
  } 

  while(my $record = $sth->fetchrow_hashref()) {
    my $instanceObj = new StackIt::DB::Instance('DBH' => $self->DBH);
    $instanceObj->ID($record->{'id'});
    $self->addMember($instanceObj);

    if($instanceObj->BuildStatus == 0) {
      if($self->_checkTimeOut($instanceObj->CreationTime)) {
        $instanceObj->BuildStatus(255);
        $instanceObj->update();
      }
    }

    $self->{'BuildStatus'} += $instanceObj->BuildStatus;
    $self->Status('failed') if($instanceObj->BuildStatus == 255);
    $records++;
  }

  $self->Status('success') if($self->BuildStatus == $records);

  $sth->finish() if($sth);
  return 0;
}

sub _checkTimeOut {
  my ($self, $creationTime) = @_;
  my $period = $self->StatusTimeOut;
  my $timeObj = new StackIt::Time();
  my $nowEpoch = $timeObj->epochTime();

  # Don't check if timeout is not set...
  return 0 if($period == 0);

  # Creation time should be in the format YYYY-MM-DD HH:MI:SS
  if($creationTime =~ m/^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/) {
    my $year   = $1;
    my $month  = $2;
    my $day    = $3;
    my $hour   = $4;
    my $minute = $5;
    my $second = $6;

    my $creationTimeEpoch = timelocal(
      $second,
      $minute,
      $hour,
      $day,
      $month - 1,
      $year
    );

    if($nowEpoch < $creationTimeEpoch + $period) {
      return 0;
    }
  }

  # We have a time out...
  return 1;
}

no Moose;

1;
