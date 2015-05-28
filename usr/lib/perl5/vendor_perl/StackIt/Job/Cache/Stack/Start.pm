package StackIt::Job::Cache::Stack::Start;

use Moose;

use StackIt::AWS::EC2::Start;
use StackIt::Collection::CFN::Resource;
use StackIt::Moose::Types;

# String Properties
has 'CacheServer' => ( is => 'rw', isa => 'Str', default => 'localhost' );

has 'AWSAccessKeyId' => ( is => 'rw', isa => 'CleanStr', default => '', required => 1);
has 'SecretKey'      => ( is => 'rw', isa => 'CleanStr', default => '', required => 1);
has 'StackName'      => ( is => 'rw', isa => 'CleanStr', default => '', required => 1);
has 'Region'         => ( is => 'rw', isa => 'CleanStr', default => '', required => 1);

# Integer Properties
has 'CachePort'           => ( is => 'rw', isa => 'Int', default => 11211 ); 
has 'CacheTTL'            => ( is => 'rw', isa => 'Int', default => 0     );

# List Properties
has 'LogLevels' => ( is => 'rw', isa => 'ArrayRef', default => sub { [ 'Errors' ] } );

# Private Methods
sub BUILD {
  my ($self) = @_;

  # Get instance id's for the stack from AWS...
  # TODO: Figure out a way to cache instance ids for each stack
  #       since this data is needed by multiple jobs...
  my $instance_ids = $self->_getInstanceIDs();

  # Stop processing if we do not have the expected data...
  return 1 unless(@{$instance_ids});
  
  my $request = new StackIt::AWS::EC2::Start();

  $request->AWSAccessKeyId($self->AWSAccessKeyId);
  $request->SecretKey($self->SecretKey);
  $request->Region($self->Region);
  $request->InstanceId($instance_ids);

  $request->post();
  $request->Log->print($self->LogLevels);

  print __PACKAGE__ . ' job run complete' . "\n";
  return 0;
}

sub _getInstanceIDs {
  my ($self) = @_;
  my $resources = new StackIt::Collection::CFN::Resource();
  my $instance_ids = [];

  $resources->StackName($self->StackName);
  $resources->AWSAccessKeyId($self->AWSAccessKeyId);
  $resources->SecretKey($self->SecretKey);
  $resources->Region($self->Region);

  $resources->populate();

  $resources->Log->print($self->LogLevels);
  return undef if(@{$resources->Log->Errors});

  # TODO:  Collections probably need a filter feature...
  foreach my $resource (@{$resources->Collection}) {
    if($resource->Type eq 'AWS::EC2::Instance') {
      push @{$instance_ids}, $resource->PhysicalID;
    }
  }

  return $instance_ids;
}

no Moose;

1;
