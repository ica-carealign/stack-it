package StackIt::AWS::RT53::Zone::List;

use Moose;

extends 'StackIt::AWS::RT53';

# String Properties
has 'Action' => ( is => 'ro', isa => 'CleanStr', default => 'hostedzone' );

sub get {
  my ($self) = @_;
  my ($url, $response, $xml_parser);

  $url = join('/', $self->BaseURL, $self->Version, $self->Action);

  $response = $self->_request('GET', $url);

  # Parse the returned XML data
  $xml_parser = new XML::Simple(
    ForceArray => [ 'HostedZone' ]
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
