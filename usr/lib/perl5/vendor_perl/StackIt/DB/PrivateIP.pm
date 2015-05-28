package StackIt::DB::PrivateIP;

use Moose;

extends 'StackIt::DB', 'StackIt::Object';

# String Properties
has 'LastUpdateTime' => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'PrivateIP'      => ( is => 'rw', isa => 'CleanStr', default => '' ); 

# Integer Properties
has 'ID' => (
  is      => 'rw',
  isa     => 'Int',
  default => 0,
  trigger => \&_load
);

# Boolean Property
has 'Active'     => ( is => 'rw', isa => 'Bool', default => 0 );
has 'Processing' => ( is => 'rw', isa => 'Bool', default => 0 );
has 'Populated'  => ( is => 'ro', isa => 'Bool', default => 0 );

# Public Methods
sub insert {
  my ($self) = @_;
  my ($sql, $sth);

  unless($self->PrivateIP) {
    $self->Log->error('Cannot insert:  PrivateIP undefined');
    return 1;
  }

  $sql  = 'INSERT INTO `private_ip` (`private_ip`, `active`, ';
  $sql .= ' `processing`) VALUES (?, ?, ?)';

  $sth = $self->DBH->prepare($sql);

  unless($sth) {
    $self->Log->error($self->DBH->errstr);
    return 1;
  }

  $sth->execute(
    $self->PrivateIP,
    $self->Active,
    $self->Processing
  );

  if($sth->errstr) {
    $self->Log->error($sth->errstr);
    return 1;
  }

  $self->{'ID'} = $self->DBH->last_insert_id(undef, undef, 'private_ip', 'id');

  $sth->finish() if($sth);
  return 0;
}

sub getFirstInactiveIP {
  my ($self) = @_;
  my ($sql, $sth);

  $self->DBH->begin_work();
  
  if($self->DBH->errstr) {
    $self->Log->error($self->DBH->errstr);
    return 1;
  }

  # We need to make sure we have a time buffer in place so we don't mistakenly
  # allocate an ip for a server that is currently being removed from AWS.
  $sql  = 'SELECT * FROM `private_ip` WHERE `active` = 0 ';
  $sql .= 'AND processing = 0 AND last_update_time <= ';
  $sql .= 'DATE_ADD(NOW(), INTERVAL -1 DAY) LIMIT 1 FOR UPDATE';

  $sth = $self->DBH->prepare($sql);

  unless($sth) {
    $self->Log->error($self->DBH->errstr);
    $self->DBH->rollback();
    return 1;
  }

  $sth->execute();

  if($sth->errstr) {
    $self->Log->error($sth->errstr);
    $self->DBH->rollback();
    return 1;
  }

  # Only one record...
  if($sth->rows) {
    my $record = $sth->fetchrow_hashref();

    $self->{'ID'}             = $record->{'id'};
    $self->{'PrivateIP'}      = $record->{'private_ip'};
    $self->{'Active'}         = $record->{'active'};
    $self->{'Processing'}     = 1;
    $self->{'LastUpdateTime'} = $record->{'last_update_time'};

    $self->update();

    if(@{$self->Log->Errors}) {
      $self->DBH->rollback();
      return 1;
    }
  }

  $self->{'Populated'} = 1;
  $sth->finish() if($sth);

  $self->DBH->commit();

  if($self->DBH->errstr) {
    $self->Log->error($self->DBH->errstr);
    return 1;
  }

  return 0;
}

sub generateNewIP {
  my ($self, $subnet) = @_;
  my ($ip, $cidr) = split('/', $subnet);
  my ($sql, $sth);

  if($cidr != 24) {
    $self->Log->error('Unknown CIDR');
    return 1;
  }

  $subnet =~ s/\d+\/\d+$//;

  $self->DBH->begin_work();
  
  if($self->DBH->errstr) {
    $self->Log->error($self->DBH->errstr);
    return 1;
  }

  $self->DBH->do('LOCK TABLES `private_ip` WRITE');

  if($self->DBH->errstr) {
    $self->Log->error($self->DBH->errstr);
    return 1;
  }

  $sql = 'SELECT MAX(`id`) AS `id` FROM `private_ip`';

  $sth = $self->DBH->prepare($sql);

  unless($sth) {
    $self->Log->error($self->DBH->errstr);
    $self->DBH->rollback();
    $self->DBH->do('UNLOCK TABLES');
    return 1;
  }

  $sth->execute();

  if($sth->errstr) {
    $self->Log->error($sth->errstr);
    $self->DBH->rollback();
    $self->DBH->do('UNLOCK TABLES');
    return 1;
  }

  # Only one record...
  if($sth->rows) {
    my $record = $sth->fetchrow_hashref();
    my $id = $record->{'id'} ? $record->{'id'} + 1 : 1;

    # TODO:  Fix to support multiple subnets...
    # Last ip of subnet is reserved by AWS...
    if($id > 254) {
      $self->Log->error('Maximum index reached');
      $self->DBH->rollback();
      $self->DBH->do('UNLOCK TABLES');
      return 1;
    }

    # Generate and save a new record...
    $self->{'ID'} = $id;
    $self->PrivateIP($subnet . $id);
    $self->Active(0);
    $self->Processing(1);

    $self->insert();

    if(@{$self->Log->Errors}) {
      $self->DBH->rollback();
      $self->DBH->do('UNLOCK TABLES');
      return 1;
    }
  }

  $sth->finish() if($sth);

  $self->DBH->commit();
  $self->DBH->do('UNLOCK TABLES');

  if($self->DBH->errstr) {
    $self->Log->error($self->DBH->errstr);
    $self->DBH->do('UNLOCK TABLES');
    return 1;
  }
}

sub update {
  my ($self) = @_;
  my ($sql, $sth);

  unless($self->ID) {
    $self->Log->error('Cannot update:  ID undefined');
    return 1;
  }

  $sql = 'UPDATE `private_ip` SET `active`=?, `processing`=? WHERE `id` = ?';

  $sth = $self->DBH->prepare($sql);

  unless($sth) {
    $self->Log->error($self->DBH->errstr);
    return 1;
  }

  $sth->execute(
    $self->Active,
    $self->Processing,
    $self->ID
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

  $sql  = 'SELECT * FROM `private_ip` WHERE `id` = ?';

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

    $self->{'ID'}             = $record->{'id'};
    $self->{'PrivateIP'}      = $record->{'private_ip'};
    $self->{'Active'}         = $record->{'active'};
    $self->{'Processing'}     = $record->{'processing'};
    $self->{'LastUpdateTime'} = $record->{'last_update_time'};
  }

  $self->{'Populated'} = 1;
  $sth->finish() if($sth);
  return 0;
}

no Moose;

1;
