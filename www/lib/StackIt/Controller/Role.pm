package StackIt::Controller::Role;

use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

sub list :Local {
  my ($self, $c, $environment) = @_;
  my ($model);

  $c->model('DB')->Role->DBH($c->model('DB')->dbh);

  if($environment && $environment =~ m/^\S+$/) {
    $model = $c->model('DB')->Role->list({
      'Environment' => $environment
    });
  } else {
    $model = $c->model('DB')->Role->list({});
  }

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
