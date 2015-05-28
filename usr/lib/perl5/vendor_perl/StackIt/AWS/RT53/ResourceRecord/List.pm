package StackIt::AWS::RT53::ResourceRecord::List;

use Moose;

extends 'StackIt::AWS::RT53';

# String Properties
has 'Action' => ( is => 'ro', isa => 'CleanStr', default => 'rrset' );
has 'Name'   => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Type'   => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'ZoneID' => ( is => 'rw', isa => 'CleanStr', default => '' );

sub get {
  my ($self) = @_;
  my ($url, $response, $xml_parser);
  my $separator = '?';

  unless($self->ZoneID) {
    $self->Log->error('Cannot get resource records: ZoneID undefined');
    return 1;
  }

  $url = join(
    '/',
    $self->BaseURL,
    $self->Version,
    'hostedzone',
    $self->ZoneID,
    $self->Action
  );

  if($self->Name) {
    $url .= $separator;
    $url .= 'name=' . $self->Name;
    $separator = '&';
  }

  if($self->Type) {
    $url .= $separator;
    $url .= 'type=' . $self->Type;
  }

  $response = $self->_request('GET', $url);

  # Parse the returned XML data
  $xml_parser = new XML::Simple(
    ForceArray => [ 'ResourceRecordSet', 'ResourceRecord' ]
  );

  if($response->code >= 500) {
    $self->Log->error('HTTP POST FAILED:  ' . $response->status_line);
    return 1;
  } else {
    $self->{'Output'} = $xml_parser->XMLin($response->content);
  }

  return 0;
}

no Moose;

1;
