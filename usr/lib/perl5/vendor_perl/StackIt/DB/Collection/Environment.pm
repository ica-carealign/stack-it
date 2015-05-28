package StackIt::DB::Collection::Environment;

use Moose;

use StackIt::DB::Environment;

extends 'StackIt::Collection', 'StackIt::DB';

# Private Methods
sub BUILD {
  my ($self) = @_;
  my ($sql, $sth);

  $sql = 'SELECT DISTINCT `environment` FROM `role`';

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
    my $envObj = new StackIt::DB::Environment( 'DBH' => $self->DBH );

    if($record->{'environment'}) {
      $envObj->Environment($record->{'environment'});
      $self->addMember($envObj);
    }
  }

  $sth->finish() if($sth);
  return 0;
}

no Moose;

1;
