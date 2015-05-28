package StackIt::DB::DNSRecord;

use Moose;

extends 'StackIt::DB', 'StackIt::Object';

# String Properties
has 'Type'     => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Name'     => ( is => 'rw', isa => 'CleanStr', default => '' );

# Integer Properties
has 'PortID' => ( is => 'rw', isa => 'Int', default => 0 );
has 'TTL'    => ( is => 'rw', isa => 'Maybe[Int]' );

has 'ID'   => (
  is      => 'rw',
  isa     => 'Int',
  default => 0,
  trigger => \&_load
);

# Boolean Properties
has 'Populated'   => ( is => 'ro', isa => 'Bool', default => 0 );

# Public Methods
sub insert {
  my ($self) = @_;
  my ($sql, $sth);

  for my $property ( 'Type', 'Name', 'PortID' ) {
    unless($self->$property) {
      $self->Log->error("Cannot insert:  $property undefined");
      return 1;
    }
  }

  $sql = 'INSERT INTO `dns_record` (`type`, `name`, `port_id`, `ttl`) '
       . 'VALUES ( ?, ?, ?, ?)';

  $sth = $self->DBH->prepare($sql);

  unless($sth) {
    $self->Log->error($self->DBH->errstr);
    return 1;
  }

  $sth->execute(
    $self->Type,
    $self->Name,
    $self->PortID,
    $self->TTL
  );

  if($sth->errstr) {
    $self->Log->error($sth->errstr);
    return 1;
  }

  $self->{'ID'} = $self->DBH->last_insert_id(undef, undef, 'dns_record', 'id');

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

  $sql = 'SELECT * FROM `dns_record` WHERE `id` = ?';

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

    $self->{'ID'}     = $record->{'id'};
    $self->{'Type'}   = $record->{'type'};
    $self->{'Name'}   = $record->{'name'};
    $self->{'PortID'} = $record->{'port_id'};
    $self->{'TTL'}    = $record->{'ttl'};
  }

  $self->{'Populated'} = 1;
  $sth->finish;
  return 0;
}

no Moose;

1;
