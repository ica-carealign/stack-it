package StackIt::DB::Role;

use Moose;

extends 'StackIt::DB', 'StackIt::Object';

# String Properties
has 'Version'      => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'OS'           => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Role'         => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Environment'  => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'CreationTime' => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Description'  => ( is => 'rw', isa => 'CleanStr', default => '' );

# Integer Properties
has 'NumberOfInstances' => ( is => 'rw', isa => 'Int', default => 0 );

has 'ID' => (
  is      => 'rw',
  isa     => 'Int',
  default => 0,
  trigger => sub { 
    my ($self) = @_;
    $self->_loadByID();
  }
);

# Boolean Property
has 'Populated' => ( is => 'ro', isa => 'Bool', default => 0 );

# Public Methods
sub upsert {
  my ($self) = @_;
  my ($sql, $sth);

  unless($self->Role) {
    $self->Log->error('Cannot insert:  Role undefined');
    return 1;
  }

  $sql = qq{
    INSERT INTO `role`
      (`role`, `version`, `environment`, `os`, `number_of_instances`, `description`)
    VALUES
      (?, ?, ?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE
      `os` = ?, `number_of_instances` = ?, `description` = ?,
      id = LAST_INSERT_ID(id)
  };

  $sth = $self->DBH->prepare($sql);

  unless($sth) {
    $self->Log->error($self->DBH->errstr);
    return 1;
  }

  $sth->execute(
    $self->Role,
    $self->Version,
    $self->Environment,
    $self->OS,
    $self->NumberOfInstances,
    $self->Description,
    $self->OS,
    $self->NumberOfInstances,
    $self->Description,
  );

  if($sth->errstr) {
    $self->Log->error($sth->errstr);
    return 1;
  }

  $self->{'ID'} = $self->DBH->last_insert_id(undef, undef, 'role', 'id');

  $sth->finish() if($sth);
  return 0;
}

sub expungeRelatedObjects {
  my ($self) = @_;
  $self->DBH->do("DELETE FROM `port` WHERE `role_id` = ?", undef, $self->ID);
  $self->DBH->do("DELETE FROM `dependency` WHERE `role_id` = ?", undef, $self->ID);
}

sub loadByRoleEnvironment {
  my ($self) = @_;
  my ($sql, $sth);

  return 0 if($self->Populated);

  for my $property ( 'Role', 'Environment' ) {
    unless($self->$property) {
      $self->Log->error("Cannot select:  $property undefined");
      return 1;
    }
  }

  $sql  = 'SELECT * FROM `role` WHERE `role` = ? and `environment` = ?';

  $sth = $self->DBH->prepare($sql);

  unless($sth) {
    $self->Log->error($self->DBH->errstr);
    return 1;
  }

  $sth->execute($self->Role, $self->Environment);

  if($sth->errstr) {
    $self->Log->error($sth->errstr);
    return 1;
  }

  # Should only be one record because of the UNIQUE constraint...
  if($sth->rows) {
    my $record = $sth->fetchrow_hashref();

    $self->{'ID'}                = $record->{'id'};
    $self->{'Role'}              = $record->{'role'};
    $self->{'Version'}           = $record->{'version'};
    $self->{'OS'}                = $record->{'os'};
    $self->{'NumberOfInstances'} = $record->{'number_of_instances'};
    $self->{'Environment'}       = $record->{'environment'};
    $self->{'CreationTime'}      = $record->{'creation_time'};
    $self->{'Description'}       = $record->{'description'};
  }

  $self->{'Populated'} = 1;
  $sth->finish() if($sth);
  return 0;
}

# Private Methods
sub _loadByID {
  my ($self) = @_;
  my ($sql, $sth);

  return 0 if($self->Populated);

  unless($self->ID) {
    $self->Log->error('Cannot select:  ID undefined');
    return 1;
  }

  $sql  = 'SELECT * FROM `role` WHERE `id` = ?';

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

    $self->{'ID'}                = $record->{'id'};
    $self->{'Role'}              = $record->{'role'};
    $self->{'Version'}           = $record->{'version'};
    $self->{'OS'}                = $record->{'os'};
    $self->{'NumberOfInstances'} = $record->{'number_of_instances'};
    $self->{'Environment'}       = $record->{'environment'};
    $self->{'CreationTime'}      = $record->{'creation_time'};
    $self->{'Description'}       = $record->{'description'};
  }

  $self->{'Populated'} = 1;
  $sth->finish() if($sth);
  return 0;
}

no Moose;

1;
