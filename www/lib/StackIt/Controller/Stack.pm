package StackIt::Controller::Stack;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

sub delete :Local {
  my ($self, $c) = @_;
  my $return = $c->model('CFN')->deleteStack($c);

  $c->stash({ json => $return });
  $c->forward($c->view('JSON'));
}

sub deletetcstacks : Local {
  my ($self, $c) = @_;
  my $return = $c->model('CFN')->deleteTCStacks($c);

  $c->stash({ json => $return });
  $c->forward($c->view('JSON'));
}

sub list :Local {
  my ($self, $c) = @_;
  my $list = $c->model('CFN')->listStacks($c);

  $c->stash({ json => $list });
  $c->forward($c->view('JSON'));
}

sub events :Local {
  my ($self, $c) = @_;
  my $list = $c->model('CFN')->listEvents($c);

  $c->stash({ json => $list });
  $c->forward($c->view('JSON'));
}

sub create :Local {
  my ($self, $c) = @_;
  my $return = $c->model('CFN')->createStack($c);

  $c->stash({ json => $return });
  $c->forward($c->view('JSON'));
}

sub instances :Local {
  my ($self, $c) = @_;
  my $instances = $c->model('EC2')->listInstances($c);

  $c->stash({ json => $instances });
  $c->forward($c->view('JSON'));
}

sub stopinstance :Local {
  my ($self, $c) = @_;
  my $return = $c->model('EC2')->stopInstance($c);
  $c->stash({ json => $return });
  $c->forward($c->view('JSON'));
}

sub stop :Local {
  my ($self, $c) = @_;
  my $return = $c->model('CFN')->stopStack($c);
  $c->stash({ json => $return });
  $c->forward($c->view('JSON'));
}

sub startinstance :Local {
  my ($self, $c) = @_;
  my $return = $c->model('EC2')->startInstance($c);
  $c->stash({ json => $return });
  $c->forward($c->view('JSON'));
}

sub start :Local {
  my ($self, $c) = @_;
  my $return = $c->model('CFN')->startStack($c);
  $c->stash({ json => $return });
  $c->forward($c->view('JSON'));
}

sub status :Local {
  my ($self, $c) = @_;
  my $instanceName = $c->request->parameters->{'InstanceName'};
  my $stackName    = $c->request->parameters->{'StackName'};
  my $statusCode   = $c->request->parameters->{'StatusCode'} || 0;
  my $json         = {};

  $c->model('DB')->Instance->DBH($c->model('DB')->dbh);

  if($instanceName) {
    $json = $c->model('DB')->Instance->updateBuildStatus(
      $instanceName,
      $statusCode
    );
  } elsif($stackName) {
    my $stackList = $c->model('CFN')->listStacks($c);
    my $fail = 0;

    foreach my $stack (@{$stackList->{'Collection'}}) {
      if($stack->{'StackName'} eq $stackName) {
        if( $stack->{'Status'} !~ m/^CREATE_COMPLETE|CREATE_IN_PROGRESS$/ ) {
          $fail = 1;
        }

        last;
      }
    }

    $json = $c->model('DB')->Instance->list(
      $stackName,
      $c->config->{'status_time_out'},
      $fail
    );
  }

  $c->stash({ json => $json });
  $c->forward($c->view('JSON'));
}

__PACKAGE__->meta->make_immutable;

1;
