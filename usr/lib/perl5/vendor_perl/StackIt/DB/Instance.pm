package StackIt::DB::Instance;

use Moose;

extends 'StackIt::DB', 'StackIt::Object';

# String Properties
has 'Instance'     => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Stack'        => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'CreationTime' => ( is => 'rw', isa => 'CleanStr', default => '' );

# Integer Properties
has 'BuildStatus' => ( is => 'rw', isa => 'Int', default => 0 );
has 'PrivateIPID' => ( is => 'rw', isa => 'Int', default => 0 );
has 'RoleID'      => ( is => 'rw', isa => 'Int', default => 0 );

has 'ID' => (
  is      => 'rw',
  isa     => 'Int',
  default => 0,
  trigger => \&_load
);

# Boolean Property
has 'Populated'   => ( is => 'ro', isa => 'Bool', default => 0 );

# Public Methods
sub insert {
  my ($self) = @_;
  my ($sql, $sth);

  for my $property ( 'Instance', 'Stack', 'PrivateIPID', 'RoleID' ) {
    unless($self->$property) {
      $self->Log->error("Cannot insert:  $property undefined");
      return 1;
    }
  }

  $sql  = 'INSERT INTO `instance` (`instance`, `stack`, ';
  $sql .= '`private_ip_id`, `role_id`) VALUES (?, ?, ?, ?)';

  $sth = $self->DBH->prepare($sql);

  unless($sth) {
    $self->Log->error($self->DBH->errstr);
    return 1;
  }

  $sth->execute(
    $self->Instance,
    $self->Stack,
    $self->PrivateIPID,
    $self->RoleID
  );

  if($sth->errstr) {
    $self->Log->error($sth->errstr);
    return 1;
  }

  $self->{'ID'} = $self->DBH->last_insert_id(undef, undef, 'instance', 'id');

  $sth->finish() if($sth);
  return 0;
}

sub delete {
  my ($self) = @_;
  my ($sql, $sth);

  unless($self->ID) {
    $self->Log->error("Cannot delete:  ID undefined");
    return 1;
  }

  $sql = 'DELETE FROM `instance` WHERE `id`=?';

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

  $sth->finish() if($sth);
  return 0;
}

sub update {
  my ($self) = @_;
  my ($sql, $sth);

  unless($self->Instance) {
    $self->Log->error('Cannot update:  Instance undefined');
    return 1;
  }

  $sql = 'UPDATE `instance` SET `build_status`=? WHERE `instance` = ?';

  $sth = $self->DBH->prepare($sql);

  unless($sth) {
    $self->Log->error($self->DBH->errstr);
    return 1;
  }

  $sth->execute(
    $self->BuildStatus,
    $self->Instance
  );

  if($sth->errstr) {
    $self->Log->error($sth->errstr);
    return 1;
  }

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

  $sql  = 'SELECT * FROM `instance` WHERE `id` = ?';

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

  # Should only be one record...
  if($sth->rows) {
    my $record = $sth->fetchrow_hashref();

    $self->{'ID'}           = $record->{'id'};
    $self->{'Instance'}     = $record->{'instance'};
    $self->{'Stack'}        = $record->{'stack'};
    $self->{'PrivateIPID'}  = $record->{'private_ip_id'};
    $self->{'RoleID'}       = $record->{'role_id'};
    $self->{'CreationTime'} = $record->{'creation_time'};
    $self->{'BuildStatus'}  = $record->{'build_status'};
  }

  $self->{'Populated'} = 1;
  $sth->finish() if($sth);
  return 0;
}

no Moose;

1;
