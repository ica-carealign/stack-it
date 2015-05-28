package StackIt::Collection::RT53::Zone;

use Moose;
use StackIt::Moose::Types;

use StackIt::RT53::Zone;
use StackIt::AWS::RT53::Zone::List;

extends 'StackIt::Collection::AWS';

# String Properties
has 'Zone' => ( is => 'ro', isa => 'CleanStr', default => '' );

# Public Methods
sub populate {
  my ($self) = @_;
  my $logs = { 'Errors' => 'error' };

  my $request = new StackIt::AWS::RT53::Zone::List();

  $request->AccessKey($self->AWSAccessKeyId);
  $request->SecretKey($self->SecretKey);

  $request->get();

  foreach my $level (keys %{$logs}) {
    if(@{$request->Log->$level}) {
      foreach my $message (@{$request->Log->$level}) {
        my $method = $logs->{$level};
        $self->Log->$method($message);
      }
    }
  }

  my $results = $request->Output->{'HostedZones'}->{'HostedZone'};

  foreach my $result (@{$results}) {
    my $zone = new StackIt::RT53::Zone();

    $zone->ID($result->{'Id'});
    $zone->Name($result->{'Name'});
    $zone->RRCount($result->{'ResourceRecordSetCount'});

    $self->addMember($zone);
  }
}

sub getZoneIDbyName {
  my ($self, $domain) = @_;

  foreach my $zone (@{$self->Collection}) {
    if($zone->Name eq $domain . '.') {
      my $id = $zone->ID;
      $id =~ s/\/hostedzone\///;
      return $id;
    }
  }

  return undef;
}

no Moose;

1;
