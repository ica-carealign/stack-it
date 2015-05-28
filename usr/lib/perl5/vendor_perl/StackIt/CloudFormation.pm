package StackIt::CloudFormation;

use Moose;
use StackIt::Moose::Types;

# String Properties
has 'StackName'    => ( is => 'rw', isa => 'AlphaNumStr', default => '' );
has 'OutputDir'    => ( is => 'rw', isa => 'PathStr',     default => '' );
has 'CFNTemplate'  => ( is => 'rw', isa => 'CleanStr',    default => '' );
has 'Description'  => ( is => 'rw', isa => 'CleanStr',    default => '' );
has 'TemplatePath' => ( is => 'rw', isa => 'PathStr',     default => '' );

has 'BaseTemplate' => (
  is      => 'rw',
  isa     => 'CleanStr',
  default => 'base.tpl'
);

# Integer Properties
has 'NoOutput' => ( is => 'rw', isa => 'Int', default => 0 );

# Object Properties
has 'Resources' => (
  is      => 'rw',
  isa     => 'ArrayRef',
  default => sub { [] }
);

# Private Methods

# Public Methods
sub addResource {
  my ($self, $resourceObj) = @_;
  push @{$self->Resources}, $resourceObj;
}

sub outputTemplate {
  my ($self) = @_;
  my $output = '';

  my $template = Template->new(
    'INCLUDE_PATH' => $self->TemplatePath
  ) || die "$Template::ERROR\n";

  $template->process(
    $self->BaseTemplate,
    {
      'Description' => $self->Description,
      'Resources' => $self->Resources,
      'Outputs' => []
    },
    \$output
  ) || die $template->error();

  if($self->OutputDir) {
    mkdir $self->OutputDir unless(-d $self->OutputDir);
    $self->CFNTemplate($self->StackName . '.cfn.tpl') unless($self->CFNTemplate);

    open(OUT, '>' . $self->OutputDir . '/' . $self->CFNTemplate) || return undef;
    print OUT $output;
    close(OUT);
  }

  return $output;
}

no Moose;

1;
