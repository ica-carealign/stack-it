package StackIt::Model::DB;

use StackIt::DB::Config;
use Moose;

extends 'Catalyst::Model::DBI';

# Object Properties...
has 'Environment' => ( is => 'ro', isa => 'Object' );
has 'Role'        => ( is => 'ro', isa => 'Object' );
has 'PrivateIP'   => ( is => 'ro', isa => 'Object' );
has 'Instance'    => ( is => 'ro', isa => 'Object' );
has 'Port'        => ( is => 'ro', isa => 'Object' );
has 'Schedule'    => ( is => 'ro', isa => 'Object' );

# Private Methods
sub BUILD {
  my ($self) = @_;

  $self->{'Environment'} = new StackIt::Model::DB::Environment();
  $self->{'Role'} = new StackIt::Model::DB::Role();
  $self->{'PrivateIP'} = new StackIt::Model::DB::PrivateIP();
  $self->{'Instance'} = new StackIt::Model::DB::Instance();
  $self->{'Port'} = new StackIt::Model::DB::Port();
  $self->{'Schedule'} = new StackIt::Model::DB::Schedule();
}

# Overridden methods

# Catalyst::Model::DBI caches not only the DBIx::Connector but also the DBH
# itself. This prevents DBIx::Connector from doing its normal ping on every
# request. So we continue to use C::M::DBI but don't trust its DBH cache.
sub dbh {
  my ($self) = @_;
  my $cached_connection = $self->connect;
  # ping and reconnect if necessary, then return.
  return $cached_connection->dbh;
}

no Moose;

# Configure C::M::DBI using our custom config files rather than the Catalyst config.
my $dbconfig = StackIt::DB::Config->new;
my ($dsn,$user,$pass,$attr) = $dbconfig->connectionParameters;
__PACKAGE__->config(
  dsn      => $dsn,
  username => $user,
  password => $pass,
  options  => $attr,
  loglevel => 1,
);

1;
