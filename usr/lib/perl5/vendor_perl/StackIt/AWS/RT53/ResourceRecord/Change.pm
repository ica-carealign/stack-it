package StackIt::AWS::RT53::ResourceRecord::Change;

use Moose;
use Template;

extends 'StackIt::AWS::RT53';

# String Properties
has 'Action'       => ( is => 'ro', isa => 'CleanStr', default => 'rrset' );
has 'Comment'      => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'FQDN'         => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'IP'           => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'TemplatePath' => ( is => 'rw', isa => 'PathStr', default => '' );
has 'ZoneID'       => ( is => 'rw', isa => 'CleanStr', default => '' );

has 'Template' => (
  is      => 'rw',
  isa     => 'CleanStr',
  default => 'rt53_change_xml.tpl'
);

sub set {
  my ($self) = @_;
  my ($url, $response, $xmlStr, $xmlParser, $template);
  my $requiredProperties = [
    'Template',
    'TemplatePath',
    'ZoneID'
  ];

  foreach my $property (@{$requiredProperties}) {
    unless($self->$property) {
      $self->Log->error('Cannot change record: ' . $property . ' undefined');
      return 1;
    }
  }

  $url = join(
    '/',
    $self->BaseURL,
    $self->Version,
    'hostedzone',
    $self->ZoneID,
    $self->Action
  );

  $template = Template->new( 'INCLUDE_PATH' => $self->TemplatePath );

  unless($template) {
    $self->Log->error($Template::ERROR);
    return 1;
  }

  unless($template->process(
    $self->Template,
    {
      'Object' => {
        'Comment' => $self->Comment,
        'FQDN'    => $self->FQDN,
        'IP'      => $self->IP
      }
    },
    \$xmlStr
  )) {
    $self->Log->error($template->error());
    return 1;
  };

  $response = $self->_request('POST', $url, $xmlStr);

  # Parse the returned XML data
  $xmlParser = new XML::Simple();

  if($response->code >= 500) {
    $self->Log->error('HTTP POST FAILED:  ' . $response->status_line);
    return 1;
  } else {
    $self->{'Output'} = $xmlParser->XMLin($response->content);
  }

  return 0;
}

no Moose;

1;
