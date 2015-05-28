package StackIt::Controller::Environment;

use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

sub list :Local {
  my ($self, $c) = @_;
  $c->model('DB')->Environment->DBH($c->model('DB')->dbh);
  $c->stash({ json => $c->model('DB')->Environment->list({}) });
  $c->forward($c->view('JSON'));
}

sub _denied :Private {
  my ($self, $c) = @_;
  $c->response->body( 'Denied' );
  $c->response->status(403);
}

__PACKAGE__->meta->make_immutable;

1;
