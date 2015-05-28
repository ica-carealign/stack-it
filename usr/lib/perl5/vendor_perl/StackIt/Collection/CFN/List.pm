package StackIt::Collection::CFN::List;

use Moose;
use StackIt::CFN::Stack;
use StackIt::Moose::Types;
use StackIt::AWS::CFN::List;
use StackIt::DB::Collection::Instance;

extends 'StackIt::Collection::AWS', 'StackIt::DB';

# Integer Properties
has 'StatusTimeOut' => ( is => 'rw', isa => 'Int', default => 0 );

# Public Methods
sub populate {
  my ($self) = @_;
  my ($request, $result);
  my $logs = { 'Errors' => 'error' };

  $request = new StackIt::AWS::CFN::List;

  $request->AWSAccessKeyId($self->AWSAccessKeyId);
  $request->SecretKey($self->SecretKey);
  $request->Region($self->Region);

  $request->post();

  foreach my $level (keys %{$logs}) {
    if(@{$request->Log->$level}) {
      foreach my $message (@{$request->Log->$level}) {
        my $method = $logs->{$level};
        $self->Log->$method($message);
      }
    }
  }

  $self->Log->debug($request->Query);
  $self->Log->debug($request->Content);

  $result = $request->Output->{'DescribeStacksResult'}->{'Stacks'};

  foreach my $data (@{$result->{'member'}}) {
    my $stack = new StackIt::CFN::Stack();

    $stack->StackName($data->{'StackName'});
    $stack->Status($data->{'StackStatus'});
    $stack->Description($data->{'Description'});
    $stack->Output($data->{'StackId'});
    $stack->CreateTime($data->{'CreationTime'});

    my $db_instances = new StackIt::DB::Collection::Instance(
      'DBH'           => $self->DBH,
      'StackName'     => $data->{'StackName'},
      'StatusTimeOut' => $self->StatusTimeOut
    );

    $stack->BuildStatus($db_instances->Status);
    $self->addMember($stack);
  }
}

no Moose;

1;
