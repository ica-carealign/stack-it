package StackIt::DB::Collection::Dependency;

use Moose;

use StackIt::DB::Dependency;

extends 'StackIt::Collection', 'StackIt::DB';

# Integrer Properties
has 'RoleID' => ( is => 'rw', isa => 'Int', default => 0 );

# Private Methods
sub BUILD {
  my ($self) = @_;
  my ($sql, $sth);

  unless($self->RoleID) {
    $self->Log->error('Cannot select:  RoleID undefined');
    return 1;
  }

  $sql = 'SELECT `id` FROM `dependency` WHERE `role_id` = ?';

  $sth = $self->DBH->prepare($sql);

  unless($sth) {
    $self->Log->error($self->DBH->errstr);
    return 1;
  }

  $sth->execute($self->RoleID);

  if($sth->errstr) {
    $self->Log->error($sth->errstr);
    return 1;
  } 

  while(my $record = $sth->fetchrow_hashref()) {
    my $dependencyObj = new StackIt::DB::Dependency( 'DBH' => $self->DBH );
    $dependencyObj->ID($record->{'id'});
    $self->addMember($dependencyObj);
  }

  $sth->finish() if($sth);
  return 0;
}

no Moose;

1;
