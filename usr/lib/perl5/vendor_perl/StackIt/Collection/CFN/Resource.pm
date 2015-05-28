package StackIt::Collection::CFN::Resource;

use Moose;
use StackIt::CFN::Resource;
use StackIt::Moose::Types;
use StackIt::AWS::CFN::Resource;

extends 'StackIt::Collection::AWS';

# String Properties
has 'StackName' => ( is => 'rw', isa => 'AlphaNumStr', default => '' );

# Public Methods
sub populate {
  my ($self) = @_;
  my ($request, $result);
  my $logs = { 'Errors' => 'error' };

  $request = new StackIt::AWS::CFN::Resource;

  $request->AWSAccessKeyId($self->AWSAccessKeyId);
  $request->SecretKey($self->SecretKey);
  $request->StackName($self->StackName);
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

  $result = $request->Output->{'DescribeStackResourcesResult'}->{'StackResources'};

  foreach my $data (@{$result->{'member'}}) {
    my $resource = new StackIt::CFN::Resource();

    $resource->LogicalID($data->{'LogicalResourceId'});
    $resource->Type($data->{'ResourceType'});
    $resource->LastUpdated($data->{'Timestamp'});
    $resource->Status($data->{'ResourceStatus'});

    if($data->{'PhysicalResourceId'}) {
      $resource->PhysicalID($data->{'PhysicalResourceId'});
    }

    $self->addMember($resource);
  }
}

no Moose;

1;
