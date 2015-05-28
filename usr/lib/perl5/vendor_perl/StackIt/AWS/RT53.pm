package StackIt::AWS::RT53;

use Data::Dumper;

use Moose;
use StackIt::Moose::Types;
use Digest::SHA;
use MIME::Base64;
use LWP::UserAgent;
use HTTP::Request;
use XML::Simple;

extends 'StackIt::Object';

# String Properties
has 'AccessKey'  => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'SecretKey'  => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Marker'     => ( is => 'rw', isa => 'CleanStr', default => '' );

has 'ServerDate' => ( is => 'ro', isa => 'CleanStr', default => '' );
has 'Signature'  => ( is => 'ro', isa => 'CleanStr', default => '' );

has 'BaseURL'    => (
  is      => 'rw',
  isa     => 'CleanStr',
  default => 'https://route53.amazonaws.com'
);

has 'SignatureMethod' => (
  is      => 'ro',
  isa     => 'CleanStr',
  default => 'HmacSHA256'
);

has 'Version' => (
  is      => 'rw',
  isa     => 'CleanStr',
  default => '2013-04-01'
);

# Integer Properties
has 'StatusCode' => ( is => 'rw', isa => 'Int', default => 0 );
has 'MaxItems'   => ( is => 'rw', isa => 'Int', default => 0 );

# List Properties
has 'Output' => ( is => 'ro', isa => 'HashRef', default => sub { {} } );

# Public Methods

# Private Methods
sub _createSignature() {
  my ($self) = @_;

  $self->_getServerDate();

  my $sig_hash = Digest::SHA::hmac_sha256($self->ServerDate, $self->SecretKey);
  $self->{'Signature'} = MIME::Base64::encode_base64($sig_hash, '');

  return 0;
}

sub _getServerDate {
  my ($self) = @_;
  my ($ua, $response, $date);

  $ua = new LWP::UserAgent();
  $response = $ua->get($self->BaseURL . '/date');

  $self->{'ServerDate'} = $response->header('date');

  unless($self->ServerDate) {
    $self->Log->error('Failed server date lookup: ' . $response->message);
    return 1;
  }

  return 0;
}

sub _request {
  my ($self, $method, $url, $content) = @_;
  my ($ua, $hmac, $signature, $request);

  $self->_createSignature();

  $ua = new LWP::UserAgent();

  my $authStr  = 'AWS3-HTTPS AWSAccessKeyId=' . $self->AccessKey;
     $authStr .= ',Algorithm=' . $self->SignatureMethod;
     $authStr .= ',Signature=' . $self->Signature;

  $request = new HTTP::Request($method => $url);

  $request->header('Content-Type' => 'text/html');
  $request->header('Date' => $self->ServerDate);
  $request->header('X-Amzn-Authorization' => $authStr);

  $request->content($content) if($content);

  my $response = $ua->request($request);

  return $response;
}

no Moose;

1;
