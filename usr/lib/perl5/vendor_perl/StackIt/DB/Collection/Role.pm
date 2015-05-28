package StackIt::DB::Collection::Role;

use Moose;

use StackIt::DB::Role;

extends 'StackIt::Collection', 'StackIt::DB';

# String Properties
has 'Environment' => ( is => 'rw', isa => 'CleanStr', default => '' );

# Private Methods
sub BUILD {
  my ($self) = @_;
  my ($sql, $sth, @parameters);

  if($self->Environment) {
    $sql = 'SELECT `id` FROM `role` WHERE `environment` = ?';
    push @parameters, $self->Environment;
  } else {
    $sql = 'SELECT `id` FROM `role`';
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
    my $roleObj = new StackIt::DB::Role( 'DBH' => $self->DBH );
    $roleObj->ID($record->{'id'});
    $self->addMember($roleObj);
  }

  $sth->finish() if($sth);
  return 0;
}

no Moose;

1;
