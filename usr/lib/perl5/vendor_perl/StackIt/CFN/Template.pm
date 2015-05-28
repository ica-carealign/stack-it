package StackIt::CFN::Template;

use Moose;
use Template;
use StackIt::Moose::Types;

# String Properties
has 'Name'         => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Template'     => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'TemplatePath' => ( is => 'rw', isa => 'PathStr', default => '' );

# Public Methods
sub processTemplate {
  my ($self) = @_;
  my $return = '';

  my $template = Template->new(
    'INCLUDE_PATH' => $self->TemplatePath
  ) || die "$Template::ERROR\n";

  $template->process(
    $self->Template,
    { 'Object' => $self },
    \$return
  ) || die $template->error();

  return $return;
}

no Moose;

1;
