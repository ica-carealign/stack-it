package StackIt::AWS;

use Moose;
use StackIt::Moose::Types;
use POSIX;
use Digest::SHA;
use MIME::Base64;
use URI;
use URI::Escape;
use LWP::UserAgent;
use XML::Simple;

extends 'StackIt::Object';

# String Properties
has 'AWSAccessKeyId' => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Action'         => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'BaseURL'        => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Content'        => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Query'          => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Region'         => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'SecretKey'      => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Signature'      => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Version'        => ( is => 'rw', isa => 'CleanStr', default => '' );

has 'SignatureMethod' => (
  is      => 'rw',
  isa     => 'CleanStr',
  default => 'HmacSHA256'
);

has 'Timestamp' => (
  is      => 'rw',
  isa     => 'CleanStr',
  default => \&_iso8601Now
);

# Integer Properties
has 'StatusCode'       => ( is => 'rw', isa => 'Int', default => 0 );
has 'SignatureVersion' => ( is => 'rw', isa => 'Int', default => 2 );

# List Properties
has 'EndPoints'  => ( is => 'ro', isa => 'HashRef', default => sub { {} } );
has 'Output'     => ( is => 'ro', isa => 'HashRef', default => sub { {} } );
has 'Properties' => ( is => 'ro', isa => 'ArrayRef', default => sub { [] } );

# Private Methods
sub _createQuery() {
  my ($self) = @_;
  my $uri = new URI($self->BaseURL);
  my @sorted = sort @{$self->Properties};
  my $elements = @{$self->Properties};
  my $query = '';

  $query .= "POST\n";
  $query .= lc($uri->host) . "\n";
  $query .= "/\n";

  for(my $i = 0; $i < $elements; $i++) {
    my $property = $sorted[$i];
    my $value = $self->$property;

    if($value eq '') {
      $self->Log->error('Cannot create query: ' . $property . ' undefined');
      return 1;
    }

    if(ref($value) eq 'ARRAY') {
      my $idx = 0;
      my @sort_this_array = ();

      for($idx = 0; $idx < @{$value}; $idx++) {
        my $name = $property . '.' . ($idx + 1);
   
        if(ref($value->[$idx]) eq 'HASH') {
          my @tmpArray = ();

          foreach my $key (keys %{$value->[$idx]}) {
            my $string  = URI::Escape::uri_escape_utf8($name . '.' . $key) . '=';
               $string .= URI::Escape::uri_escape_utf8($value->[$idx]->{$key});
            push @tmpArray, $string;
          }

          $self->{'Content'} .= join('&', sort @tmpArray);
          $self->{'Content'} .= '&' if($idx != $#{$value});
        } else {
          my $string  = URI::Escape::uri_escape_utf8($name) . '=';
             $string .= URI::Escape::uri_escape_utf8(${$value}[$idx]);
          push @sort_this_array, $string;
        }
      }

      if(@sort_this_array) {
        $self->{'Content'} .= join('&', sort _sortByKeyIdx @sort_this_array);
      }

      $self->{'Content'} .= '&' if($idx > 0);
    } else {
      $self->{'Content'} .= URI::Escape::uri_escape_utf8($property) . '=';
      $self->{'Content'} .= URI::Escape::uri_escape_utf8($value);
      $self->{'Content'} .= '&' if($i != $#sorted);
    }
  }

  $self->Query($query . $self->Content);

  return 0;
}

sub _createSignature() {
  my ($self) = @_;
  my $properties = [
    'Query',
    'SecretKey'
  ];

  foreach my $property (@{$properties}) {
    unless($self->$property) {
      $self->Log->error('Cannot create signature: ' . $property . ' undefined');
      return 1;
    }
  }

  my $sig_hash = Digest::SHA::hmac_sha256($self->Query, $self->SecretKey);
  $self->Signature(MIME::Base64::encode_base64($sig_hash, ''));

  return 0;
}

sub _iso8601Now() {
  my ($self) = @_;
  my ($now, $tz, $timestamp);

  $now = time();

  $tz = strftime("%z", localtime($now));
  $tz =~ s/(\d{2})(\d{2})/$1:$2/;

  $timestamp = POSIX::strftime("%Y-%m-%dT%H:%M:%S", localtime($now));
  
  return $self->Timestamp($timestamp . $tz);
}

sub _setBaseURLbyRegion {
  my ($self) = @_;

  if($self->Region) {
    if(exists $self->EndPoints->{$self->Region}) {
      $self->BaseURL('https://' . $self->EndPoints->{$self->Region});
      return 0;
    }
  }

  return 1;
}

# Private Function
sub _sortByKeyIdx {
  my ($aNum) = $a =~ m/\.(\d+)=/;
  my ($bNum) = $b =~ m/\.(\d+)=/;
  ($aNum || 0) cmp ($bNum || 0);
}

# Public Methods
sub post {
  my ($self) = @_;
  my ($ua, $request, $xml_parser);

  $self->_createQuery();
  $self->_createSignature();

  $self->{'Content'} .= '&Signature=';
  $self->{'Content'} .= URI::Escape::uri_escape_utf8($self->Signature);

  $ua = new LWP::UserAgent();
  $ua->env_proxy();

  $request = $ua->post($self->BaseURL, Content => $self->Content);

  $self->StatusCode($request->code);

  $xml_parser = new XML::Simple(
    ForceArray => qr/(?:item|Errors|member)/i,
    KeyAttr => '',
    SuppressEmpty => undef
  );

  if($request->code >= 500) {
    $self->Log->error('HTTP POST FAILED:  ' . $request->status_line);
    return 1;
  } else {
    $self->{'Output'} = $xml_parser->XMLin($request->content);
  }

  return 0;
}

no Moose;

1;
