package StackIt::DB::Port;

use Moose;

use StackIt::DB::DNSRecord;

extends 'StackIt::DB', 'StackIt::Object';

# String Properties
has 'Provides' => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Use'      => ( is => 'rw', isa => 'CleanStr', default => '' );

# Integer Properties
has 'RoleID' => ( is => 'rw', isa => 'Int', default => 0 );

has 'ID'   => (
  is      => 'rw',
  isa     => 'Int',
  default => 0,
  trigger => \&_load
);

has 'Port' => ( is => 'rw', isa => 'Int', default => 0 );

# Boolean Properties
has 'TCP'         => ( is => 'rw', isa => 'Bool', default => 0 );
has 'UDP'         => ( is => 'rw', isa => 'Bool', default => 0 );
has 'External'    => ( is => 'rw', isa => 'Bool', default => 0 );
has 'Inbound'     => ( is => 'rw', isa => 'Bool', default => 0 );
has 'Outbound'    => ( is => 'rw', isa => 'Bool', default => 0 );
has 'Clusterable' => ( is => 'rw', isa => 'Bool', default => 0 );
has 'Populated'   => ( is => 'ro', isa => 'Bool', default => 0 );

# List Properties
has 'DNSRecords'  => ( is => 'ro', isa => 'ArrayRef', default => sub { [] } );

# Public Methods
sub insert {
  my ($self) = @_;
  my ($sql, $sth);

  for my $property ( 'Port', 'RoleID', 'Provides' ) {
    unless($self->$property) {
      $self->Log->error("Cannot insert:  $property undefined");
      return 1;
    }
  }

  $sql  = 'INSERT INTO `port` (`provides`, `port`, `role_id`, `tcp`,';
  $sql .= ' `udp`, `external`, `inbound`, `outbound`, `clusterable`,';
  $sql .= ' `use`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';

  $sth = $self->DBH->prepare($sql);

  unless($sth) {
    $self->Log->error($self->DBH->errstr);
    return 1;
  }

  $sth->execute(
    $self->Provides,
    $self->Port,
    $self->RoleID,
    $self->TCP,
    $self->UDP,
    $self->External,
    $self->Inbound,
    $self->Outbound,
    $self->Clusterable,
    $self->Use
  );

  if($sth->errstr) {
    $self->Log->error($sth->errstr);
    return 1;
  }

  $self->{'ID'} = $self->DBH->last_insert_id(undef, undef, 'port', 'id');

  $sth->finish() if($sth);

  for my $dnsRecord (@{$self->DNSRecords}) {
    $dnsRecord->PortID($self->ID);
    $dnsRecord->insert();
  }

  return 0;
}

sub addDNSRecord {
  my ($self,$dnsRecordObj) = @_;
  if(ref($dnsRecordObj) ne 'StackIt::DB::DNSRecord') {
    $self->Log->error('Invalid DNSRecord object!');
    return 1;
  }

  push @{$self->DNSRecords}, $dnsRecordObj;
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

  $sql = 'SELECT * FROM `port` WHERE `id` = ?';
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

    $self->{'ID'}          = $record->{'id'};
    $self->{'RoleID'}      = $record->{'role_id'};
    $self->{'Provides'}    = $record->{'provides'};
    $self->{'Port'}        = $record->{'port'};
    $self->{'TCP'}         = $record->{'tcp'};
    $self->{'UDP'}         = $record->{'udp'};
    $self->{'External'}    = $record->{'external'};
    $self->{'Inbound'}     = $record->{'inbound'};
    $self->{'Outbound'}    = $record->{'outbound'};
    $self->{'Clusterable'} = $record->{'clusterable'};
    $self->{'Use'}         = $record->{'use'};
  }

  $sth->finish() if($sth);

  $sql = "SELECT `id` FROM `dns_record` WHERE `port_id` = ?";
  $sth = $self->DBH->prepare($sql);
  my @ids = @{ $self->DBH->selectcol_arrayref($sql, undef, $self->ID) };

  $self->{'DNSRecords'} = [];
  for my $id (@ids) {
    my $dnsRecord = StackIt::DB::DNSRecord->new(DBH => $self->DBH);
    $dnsRecord->ID($id);
    push @{$self->{'DNSRecords'}}, $dnsRecord;
  }

  $self->{'Populated'} = 1;


  return 0;
}

no Moose;

1;
