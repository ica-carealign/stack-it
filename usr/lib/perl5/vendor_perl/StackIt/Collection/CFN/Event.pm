package StackIt::Collection::CFN::Event;

use Moose;
use StackIt::CFN::Event;
use StackIt::Moose::Types;
use StackIt::AWS::CFN::Event;

extends 'StackIt::Collection::AWS';

# String Properties
has 'StackName' => ( is => 'rw', isa => 'AlphaNumStr', default => '' );

# Public Methods
sub populate {
  my ($self) = @_;
  my ($request, $result);
  my $logs = { 'Errors' => 'error' };

  $request = new StackIt::AWS::CFN::Event;

  $request->AWSAccessKeyId($self->AWSAccessKeyId);
  $request->SecretKey($self->SecretKey);
  $request->Region($self->Region);
  $request->StackName($self->StackName);

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

  $result = $request->Output->{'DescribeStackEventsResult'}->{'StackEvents'};

  foreach my $data (@{$result->{'member'}}) {
    my $event = new StackIt::CFN::Event();

    $event->LogicalID($data->{'LogicalResourceId'});
    $event->StackName($data->{'StackName'});
    $event->Status($data->{'ResourceStatus'});
    $event->Type($data->{'ResourceType'});
    $event->Timestamp($data->{'Timestamp'});

    if($data->{'ResourceStatusReason'}) {
      $event->Reason($data->{'ResourceStatusReason'});
    }

    $self->addMember($event);
  }
}

no Moose;

1;
