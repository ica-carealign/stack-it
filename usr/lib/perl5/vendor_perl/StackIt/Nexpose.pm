package StackIt::Nexpose;

use Moose;
use LWP::UserAgent;
use Net::SSL;
use XML::Simple;
use StackIt::Moose::Types;
use StackIt::Log;

# String Properties
has 'UA'  => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'URL' => ( is => 'rw', isa => 'CleanStr', default => '' );

# Log Object
has 'Log' =>(
  is      => 'rw',
  isa     => 'Log',
  default => sub { return new StackIt::Log(); }
);

# Private Methods
sub BUILD {
  my ($self) = @_;

  $self->{'UA'} = LWP::UserAgent->new;
  $self->UA->env_proxy;
}

sub _post {
  my ($self, $body, $returnXML) = @_;

  my $request = HTTP::Request->new(POST => $self->URL);

  $request->content_type('text/xml');
  $request->content($body);

  my $response = $self->UA->request($request);

  if($response->is_success) {
    if($returnXML) {
      return $response->content;
    } else {
      return XMLin($response->content);
    }
  }

  $self->Log->error('POST FAILURE: ' .  $response->status_line);
  return undef;
}

no Moose;

1;
