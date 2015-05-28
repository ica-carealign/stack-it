package StackIt::Collection::RT53::ResourceRecord;

use Moose;
use StackIt::Moose::Types;

use StackIt::RT53::ResourceRecord;
use StackIt::AWS::RT53::ResourceRecord::List;

extends 'StackIt::Collection::AWS';

# String Properties
has 'ZoneID' => ( is => 'rw', isa => 'CleanStr', default => '' );

# Public Methods
sub populate {
  my ($self) = @_;
  my $logs = { 'Errors' => 'error' };

  my $request = new StackIt::AWS::RT53::ResourceRecord::List();

  $request->AccessKey($self->AWSAccessKeyId);
  $request->SecretKey($self->SecretKey);
  $request->ZoneID($self->ZoneID);

  $request->get();

  foreach my $level (keys %{$logs}) {
    if(@{$request->Log->$level}) {
      foreach my $message (@{$request->Log->$level}) {
        my $method = $logs->{$level};
        $self->Log->$method($message);
      }
    }
  }

  my $results = $request->Output->{'ResourceRecordSets'}->{'ResourceRecordSet'};

  foreach my $result (@{$results}) {
    my $resourceRecord = new StackIt::RT53::ResourceRecord();

    $resourceRecord->FQDN($result->{'Name'});
    $resourceRecord->Type($result->{'Type'});
    $resourceRecord->TTL($result->{'TTL'});

    foreach my $record (@{$result->{'ResourceRecords'}->{'ResourceRecord'}}) {
      $resourceRecord->addValue($record->{'Value'});
    }

    $self->addMember($resourceRecord);
  }
}

sub getARecordByFQDN {
  my ($self, $fqdn) = @_;

  foreach my $resourceRecord (@{$self->Collection}) {
    if($resourceRecord->Type eq 'A' && $resourceRecord->FQDN eq $fqdn . '.') {
      return $resourceRecord;
    }
  }

  return undef;
}

no Moose;

1;
