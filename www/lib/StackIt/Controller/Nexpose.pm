package StackIt::Controller::Nexpose;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

sub scan :Local {
  my ($self, $c) = @_;
  my $return = $c->model('Nexpose')->scan($c);

  $c->stash({ json => $return });
  $c->forward($c->view('JSON'));
}

__PACKAGE__->meta->make_immutable;

1;
