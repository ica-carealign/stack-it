package StackIt::Model::DB::Instance;

use Moose;

use StackIt::DB::Instance;
use StackIt::DB::Role;
use StackIt::DB::PrivateIP;
use StackIt::DB::Collection::Instance;

extends 'StackIt::Model::Utils';

# Public Methods
sub save {
  my ( $self, $stackName, $instanceInput, $ipObj ) = @_;
  my ($roleID, $instanceObj);

  if($instanceInput->{'Role'} && $instanceInput->{'Environment'}) {
    # Look up role record by role and environment...
    my $roleObj = new StackIt::DB::Role('DBH' => $self->DBH);

    $roleObj->Role($instanceInput->{'Role'});
    $roleObj->Environment($instanceInput->{'Environment'});

    $roleObj->loadByRoleEnvironment();

    $self->_logMessages($roleObj);
    return 1 if(@{$roleObj->Log->Errors});

    $roleID = $roleObj->ID;
  } else {
    $roleID = 1;
  }

  # Insert instance record...
  $instanceObj = new StackIt::DB::Instance('DBH' => $self->DBH);

  $instanceObj->Instance($instanceInput->{'InstanceName'});
  $instanceObj->Stack($stackName);
  $instanceObj->PrivateIPID($ipObj->ID);
  $instanceObj->RoleID($roleID);

  $instanceObj->insert();

  $self->_logMessages($instanceObj);
  return 1 if(@{$instanceObj->Log->Errors});

  # Update PrivateIP record...
  $ipObj->Active(1);
  $ipObj->Processing(0);
  $ipObj->update();

  $self->_logMessages($ipObj);
  return 1 if(@{$ipObj->Log->Errors});

  return 0;
}

sub delete {
  my ($self, $stackName) = @_;

  my $collection = new StackIt::DB::Collection::Instance(
    'DBH' => $self->DBH,
    'StackName' => $stackName
  );

  $self->_logMessages($collection);
  return 1 if(@{$collection->Log->Errors});

  foreach my $instanceObj (@{$collection->Collection}) {
    # Update private_ip record...
    my $ipObj = new StackIt::DB::PrivateIP('DBH' => $self->DBH);

    $ipObj->ID($instanceObj->PrivateIPID);

    $ipObj->Processing(0);
    $ipObj->Active(0);
    $ipObj->update();

    $self->_logMessages($ipObj);
    return 1 if(@{$ipObj->Log->Errors});

    # Delete instance record...
    $instanceObj->delete();

    $self->_logMessages($instanceObj);
    return 1 if(@{$instanceObj->Log->Errors});
  }

  return 0;
}

sub list {
  my ($self, $stackName, $timeout, $fail) = @_;

  my $collection = new StackIt::DB::Collection::Instance(
    'DBH'           => $self->DBH,
    'StackName'     => $stackName,
    'StatusTimeOut' => $timeout || 0
  );

  $collection->Status('failed') if($fail);

  $self->_logMessages($collection);
  return $self->_convertCollectionToHash($collection);  
}

sub updateBuildStatus {
  my ($self, $instanceName, $statusCode) = @_;

  my $instanceObj = new StackIt::DB::Instance(
    'DBH' => $self->DBH,
    'Instance' => $instanceName
  );

  $instanceObj->BuildStatus($statusCode);
  $instanceObj->update();

  $self->_logMessages($instanceObj);
  return 1 if(@{$instanceObj->Log->Errors});

  return 0;
}

# Private Methods

no Moose;

1;
