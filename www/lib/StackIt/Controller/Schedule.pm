package StackIt::Controller::Schedule;

use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

sub list :Local {
  my ($self, $c) = @_;
  my ($model);

  $c->model('DB')->Schedule->DBH($c->model('DB')->dbh);

  $model = $c->model('DB')->Schedule->list({});

  $c->stash({ json => $model });
  $c->forward($c->view('JSON'));
}

sub _denied :Private {
  my ($self, $c) = @_;
  $c->response->body( 'Denied' );
  $c->response->status(403);
}

__PACKAGE__->meta->make_immutable;

1;
