package StackIt::Collection::EC2::DNS;

use Moose;
use Data::Dumper;

use StackIt::Moose::Types;
use StackIt::AWS::EC2::Tag::List;
use StackIt::EC2::DNS;

extends 'StackIt::Collection::AWS';

# String Properties

# List Properties
has 'TmpTags' => ( is => 'rw', isa => 'HashRef', default => sub { {} } );

# Public Methods
sub populate {
  my ($self) = @_;
  my $logs = { 'Errors' => 'error' };

  my $request = new StackIt::AWS::EC2::Tag::List();

  $request->AWSAccessKeyId($self->AWSAccessKeyId);
  $request->SecretKey($self->SecretKey);
  $request->Region($self->Region);

  $request->addFilter({
    'Name'    => 'key',
    'Value.1' => 'dns'
  });

  $request->post();

  foreach my $level (keys %{$logs}) {
    if(@{$request->Log->$level}) {
      foreach my $message (@{$request->Log->$level}) {
        my $method = $logs->{$level};
        $self->Log->$method($message);
      }
    }
  }

  $self->Log->debug('QUERY:  ' . $request->Query);
  $self->Log->debug('CONTENT:  ' . $request->Content);
  $self->Log->debug('OUTPUT:  ' . Dumper($request->Output));

  my $results = $request->Output->{'tagSet'}->{'item'};

  foreach my $result (@{$results}) {
    my $instanceID = $result->{'resourceId'};

    $self->_checkTmpObjects($instanceID);

    my $tag = $self->TmpTags->{$instanceID};

    if($result->{'key'} eq 'dns') {
      my @fields = split('\|', $result->{'value'});

      $tag->FQDN(&_checkValue($fields[0]));
      $tag->RootZone(&_checkValue($fields[1]));
    }

  }

  foreach my $instanceID (keys %{$self->TmpTags}) {
    $self->addMember($self->TmpTags->{$instanceID});
  }

  # Cleanup...
  $self->TmpTags({});
}

# Private Methods
sub _checkTmpObjects {
  my ($self, $instanceID) = @_;
  return if(exists $self->TmpTags->{$instanceID});
  $self->TmpTags->{$instanceID} = new StackIt::EC2::DNS();
  $self->TmpTags->{$instanceID}->InstanceID($instanceID);
}

sub _checkValue {
  my ($value, $isInt) = @_;
  return $value =~ m/^[0-9]+/ ? $value : 0 if($isInt);
  return $value ? $value : '';
}

no Moose;

1;
