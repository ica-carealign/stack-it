package StackIt::DB::Dependency;

use Moose;

extends 'StackIt::DB', 'StackIt::Object';

# String Properties
has 'Dependency' => ( is => 'rw', isa => 'CleanStr', default => '' );

# Integer Properties
has 'RoleID' => ( is => 'rw', isa => 'Int', default => 0 );

has 'ID'   => (
  is      => 'rw',
  isa     => 'Int',
  default => 0,
  trigger => \&_load
);

# Boolean Property
has 'Populated' => ( is => 'ro', isa => 'Bool', default => 0 );

# Public Methods
sub insert {
  my ($self) = @_;
  my ($sql, $sth);

  for my $property ( 'RoleID', 'Dependency' ) {
    unless($self->$property) {
      $self->Log->error("Cannot insert:  $property undefined");
      return 1;
    }
  }

  $sql  = 'INSERT INTO `dependency` (`role_id`,';
  $sql .= ' `dependency`) VALUES (?, ?)';

  $sth = $self->DBH->prepare($sql);

  unless($sth) {
    $self->Log->error($self->DBH->errstr);
    return 1;
  }

  $sth->execute(
    $self->RoleID,
    $self->Dependency
  );

  if($sth->errstr) {
    $self->Log->error($sth->errstr);
    return 1;
  }

  $self->{'ID'} = $self->DBH->last_insert_id(undef, undef, 'dependency', 'id');

  $sth->finish() if($sth);
  return 0;
}

# Private Methods
sub _load {
  my ($self) = @_;
  my ($sql, $sth);

  return 0 if($self->Populated);

  unless($self->ID) {
    $self->Log->error('Cannot select:  ID undefined');
    return 1;
  }

  $sql  = 'SELECT * FROM `dependency` WHERE `id` = ?';

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

    $self->{'ID'}         = $record->{'id'};
    $self->{'RoleID'}     = $record->{'role_id'};
    $self->{'Dependency'} = $record->{'dependency'};
  }

  $self->{'Populated'} = 1;
  $sth->finish() if($sth);
  return 0;
}

no Moose;

1;
