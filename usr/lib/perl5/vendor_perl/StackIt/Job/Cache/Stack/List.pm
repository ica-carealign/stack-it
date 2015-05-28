package StackIt::Job::Cache::Stack::List;

use Moose;

use Cache::Memcached;
use StackIt::Collection::CFN::List;
use StackIt::Moose::Types;
use StackIt::DB::Config;

# String Properties
has 'CacheServer' => ( is => 'rw', isa => 'Str', default => 'localhost' );

has 'AWSAccessKeyId' => ( is => 'rw', isa => 'CleanStr', default => '', required => 1);
has 'SecretKey'      => ( is => 'rw', isa => 'CleanStr', default => '', required => 1);
has 'Region'         => ( is => 'rw', isa => 'CleanStr', default => '', required => 1);

# Integer Properties
has 'CachePort'    => ( is => 'rw', isa => 'Int', default => 11211 ); 
has 'CacheTTL'     => ( is => 'rw', isa => 'Int', default => 0     );
has 'StatusTimeOut' => ( is => 'rw', isa => 'Int', default => 0     );

# Object Properties
has 'DBH' => ( is => 'rw', isa => 'Object' );

# Private Methods
sub BUILD {
  my ($self) = @_;
  my ($cache, $collection);

  $self->_dbConnect();

  $cache = new Cache::Memcached();
  $cache->set_servers([ $self->CacheServer . ':' . $self->CachePort ]);

  $collection = new StackIt::Collection::CFN::List(DBH => $self->DBH);

  $collection->AWSAccessKeyId($self->AWSAccessKeyId);
  $collection->SecretKey($self->SecretKey);
  $collection->Region($self->Region);
  $collection->StatusTimeOut($self->StatusTimeOut);

  $collection->populate();

  $collection->Log->print(['Info', 'Warnings', 'Errors']);

  return 1 if(@{$collection->Log->Errors});

  $cache->set(
    'stackitstack-list',
    $collection->toHash(),
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
