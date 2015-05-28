package StackIt::Definition::Role::Port;

use Moose;
use StackIt::Moose::Types;

# String Properties
has 'Use' => ( is => 'rw', isa => 'CleanStr', default => '' );

# Boolean Properties
has 'TCP'         => ( is => 'rw', isa => 'Bool', default => 0 );
has 'UDP'         => ( is => 'rw', isa => 'Bool', default => 0 );
has 'External'    => ( is => 'rw', isa => 'Bool', default => 0 );
has 'Inbound'     => ( is => 'rw', isa => 'Bool', default => 0 );
has 'Outbound'    => ( is => 'rw', isa => 'Bool', default => 0 );
has 'Clusterable' => ( is => 'rw', isa => 'Bool', default => 0 );

# Integer Properties
has 'Port' => ( is => 'rw', isa => 'Int', default => 0 );

# List Properties
has 'DNSRecords' => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );

sub addDNSRecord {
  my ($self,$dnsRecordObj) = @_;
  if (ref($dnsRecordObj) ne 'StackIt::Definition::Role::Port::DNSRecord') {
    print STDERR "Invalid DNSRecord object!\n";
    return 1;
  }

  push @{$self->DNSRecords}, $dnsRecordObj;
  return 0;
}

no Moose;

1;
