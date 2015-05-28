package StackIt::Job::Cache::InstanceList;

use Moose;

use Cache::Memcached;
use StackIt::Collection::CFN::Resource;
use StackIt::Collection::EC2::Instance;
use StackIt::DB::Collection::Instance;
use StackIt::DB::Config;

# String Properties
has 'CacheServer' => ( is => 'rw', isa => 'Str', default => 'localhost' );

has 'AWSAccessKeyId' => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'SecretKey'      => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'StackName'      => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'Region'         => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'RootZone'       => ( is => 'rw', isa => 'CleanStr', default => '' );

# Integer Properties
has 'CachePort'    => ( is => 'rw', isa => 'Int', default => 11211 ); 
has 'CacheTTL'     => ( is => 'rw', isa => 'Int', default => 0     );
has 'StackTimeOut' => ( is => 'rw', isa => 'Int', default => 0     );

# Object Properties
has 'DBH' => ( is => 'rw', isa => 'Object' );

# Private Methods
sub BUILD {
  my ($self) = @_;
  my ($cache, $resources, $instances);
  my $instance_ids = [];

  $self->_dbConnect();

  $cache = new Cache::Memcached();
  $cache->set_servers([ $self->CacheServer . ':' . $self->CachePort ]);

  $resources = new StackIt::Collection::CFN::Resource();

  $resources->StackName($self->StackName);
  $resources->AWSAccessKeyId($self->AWSAccessKeyId);
  $resources->SecretKey($self->SecretKey);
  $resources->Region($self->Region);

  $resources->populate();

  $resources->Log->print(['Info', 'Warnings', 'Errors']);
  return 1 if(@{$resources->Log->Errors});

  foreach my $resource (@{$resources->Collection}) {
    if($resource->Type eq 'AWS::EC2::Instance') {
      push @{$instance_ids}, $resource->PhysicalID;
    }
  }

  return unless(@{$instance_ids});

  $instances = new StackIt::Collection::EC2::Instance();

  $instances->InstanceIDs($instance_ids);
  $instances->StackName($self->StackName);
  $instances->AWSAccessKeyId($self->AWSAccessKeyId);
  $instances->SecretKey($self->SecretKey);
  $instances->Region($self->Region);
  $instances->RootZone($self->RootZone);

  $instances->populate();

  $instances->Log->print(['Info', 'Warnings', 'Errors']);
  return 1 if(@{$instances->Log->Errors});

  # TODO:  This is not a good way to merge these two collections...
  my $db_instances = new StackIt::DB::Collection::Instance(
    'DBH'           => $self->DBH,
    'StackName'     => $self->StackName,
    'StatusTimeOut' => $self->StackTimeOut
  );

  $db_instances->Log->print(['Info', 'Warnings', 'Errors']);
  return 1 if(@{$db_instances->Log->Errors});

  foreach my $instance (@{$instances->Collection}) {
    if($instance->PrivateIP) {
      my @octets = split(/\./, $instance->PrivateIP);

      foreach my $db_instance (@{$db_instances->Collection}) {
        if($db_instance->PrivateIPID eq $octets[3]) {
          $instance->BuildStatus($db_instance->BuildStatus);
          last;
        }
      }
    }
  }

  $cache->set(
    'stackit' . $self->StackName . '-instance-list',
    $instances->toHash(),
    $self->CacheTTL
  );

  $self->DBH->disconnect();

  print __PACKAGE__ . ' job run complete' . "\n";

  return 0;
}

sub _dbConnect {
  my ($self) = @_;
  my $dbh = StackIt::DB::Config->new->connect;

  local $dbh->{'AutoCommit'} = 1;
  local $dbh->{'RaiseError'} = 1;

  $self->DBH($dbh);
}

no Moose;

1;
