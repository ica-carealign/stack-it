package StackIt::DB::Config;
use strict;
use warnings;
use Scalar::Util ();
use Moose;

use StackIt::Env;

has _settings => (is => 'rw', isa => 'HashRef');

sub BUILD {
  my ($self) = @_;
  my %settings;

  for my $file ($self->_configFiles) {
    my $parsed = $self->_parseConfigFile($file);
    %settings = (%settings, %$parsed);
  }

  $self->_settings(\%settings);
}

sub connectionDetails {
  my $self = shift;
  my $env = shift || StackIt::Env->Environment;

  my %details = (
    %{ $self->_settings->{defaults} || {} },
    %{ $self->_settings->{$env}     || {} },
  );

  if (! %details) {
    return;
  }

  if (! $details{driver}) {
    die sprintf "No 'driver' is configured for '%s' in '%s'",
      $env, StackIt::Env->ConfigDirectory;
  }

  $details{dsn} = $self->buildDsn(\%details);

  my %attr_defaults = (
    AutoCommit => 1,
    RaiseError => 1,
    PrintError => 0,
  );
  my $attr = $details{attr} || {};
  while (my ($key,$val) = each %attr_defaults) {
    $attr->{$key} = $val unless exists($attr->{$key});
  }
  $details{attr} = $attr;

  return \%details;
}

sub buildDsn {
  my ($self,$details) = @_;

  my ($driver,$database,$host,$port,$opts) =
    map { $details->{$_} } qw(driver database host port options);

  no warnings 'uninitialized';
  my @driver_params;
  push @driver_params, "database=$database" if length $database;
  push @driver_params, "host=$host" if length $host;
  push @driver_params, "port=$port" if length $port;

  # support mysql_client_found_rows, etc.
  if ($opts) {
    my $reftype = ref($opts);
    if ($reftype eq 'HASH') {
      push @driver_params, map { "$_=$opts->{$_}" } keys(%$opts);
    }
    elsif ($reftype eq 'ARRAY') {
      push @driver_params, @$opts;
    }
    else {
      # If this is already a string, this will have no effect.
      # If it's some type of object reference, this will stringify.
      push @driver_params, "$opts";
    }
  }

  return join ":", "DBI", $driver, join(";", @driver_params);
}

sub connectionParameters {
  my $self = shift;
  my $env = shift || StackIt::Env->Environment;
  my $details = $self->connectionDetails($env);
  if (! $details) {
    return;
  }
  return @$details{'dsn','username','password','attr'};
}

sub connect {
  my $self = shift;
  my $env = shift || StackIt::Env->Environment;
  my @params = $self->connectionParameters($env)
    or die "no connection parameters are defined for '$env'";
  require DBI;
  return DBI->connect(@params);
}

sub _parseConfigFile {
  my ($self,$filename) = @_;
  my ($ext) = ($filename =~ /.*\.(.*)/);
  $ext ||= '';
  if ($ext =~ /^ya?ml$/i) {
    return $self->_parseYaml($filename);
  }
  elsif ($ext =~ /^json$/i) {
    return $self->_parseJson($filename);
  }
  else {
    die "unrecognized file extension '$ext' for '$filename'";
  }
}

sub _parseYaml {
  my ($self,$filename) = @_;
  require YAML::Tiny;
  my $docset = YAML::Tiny->read($filename);
  my $doc = $docset->[0];
  if (Scalar::Util::reftype($doc) ne 'HASH') {
    die "'$filename' should contain a YAML hash, not a " . ref($doc);
  }
  return $doc;
}

sub _parseJson {
  my ($self,$filename) = @_;
  require JSON::XS;
  open my $JSONFILE, "<", $filename or die "can't open '$filename': $!";
  binmode $JSONFILE, ":encoding(UTF-8)";
  my $json = do { local $/; <$JSONFILE> };
  my $doc = JSON::XS->new->utf8->relaxed->decode($json);
  if (Scalar::Util::reftype($doc) ne 'HASH') {
    die "'$filename' should contain a JSON hash/object, not a " . ref($doc);
  }
  return $doc;
}

sub _configFiles {
  my ($self) = @_;
  my $dir = StackIt::Env->ConfigDirectory;
  opendir(my $CONFIG, $dir) || do {
    warn "can't opendir '$dir': $!";
    return;
  };
  my @files = grep { /^database/i && /\.(?:ya?ml|json)$/i } readdir($CONFIG);
  closedir($CONFIG);

  return map { "$dir/$_" } sort @files;
}

no Moose;
1;

=head1 NAME

StackIt::DB::Config - Provides database connection configuration

=head1 SYNOPSIS

  use StackIt::DB::Config;

  my $cfg = StackIt::DB::Config->new();

  # get raw details hash
  my $details = $cfg->connectionDetails('production')
    || die "production connection parameters are not configured!";
  print "Will connect to $details->{driver} on $details->{host}...\n";

  # get DBI connection details by environment:
  my ($dsn,$user,$pass,$attr) = $cfg->connectionParameters('production')
    or die "production connection parameters are not configured!";
  my $dbh = DBI->connect($dsn,$user,$pass,$attr) || die $DBI::errstr;

  # or more directly:
  my $dbh = $cfg->connect('production');  
  my $dbh = $cfg->connect;  # uses STACKIT_ENV

=head1 DESCRIPTION

This module provides easy access to the StackIt database connection details.

The connection details should be kept in /etc/stack-it/database*.yaml, in a
format like so:

  defaults:
    driver: mysql
    database: stack_it

  development:
    username: root
    password: supersecret
    host: localhost

The files are read in lexical order, which allows you to have the following
setup, where later files can override earier ones.

=over 4

=item /etc/stack-it/database-00-development.yaml

=item /etc/stack-it/database-50-qa.yaml

=item /etc/stack-it/database-99-production.yaml

=back

=head2 CONSTRUCTOR

=over 4

=item new()

Creates a new instance of the L<StackIt::DB::Config> class. The configuration
is read in immediately and if there are any errors, this will raise an error.

The configuration directory can be influenced by setting the C<STACKIT_CONF>
environment variable. The default location is C</etc/stack-it>.

=back

=head2 METHODS

=over 4

=item connectionDetails

=item connectionDetails(environment)

Returns a hash containing the raw connection details parsed from the
configuration files. If C<environment> is not provided, defaults to
C<STACKIT_ENV> and then C<'production'>.

  print Data::Dump::dump($cfg->connectionDetails), "\n";

  # prints:
  {
    driver => 'mysql',
    username => 'root',
    password => 'supersecret',
    host => 'localhost'
  }

=item connectionParameters

=item connectionParameters(environment)

Returns a four-element list containing the data source, username, password and
connection attributes that C<DBI-E<gt>connect> expects. If C<environment> is
not provided, defaults to C<STACKIT_ENV> and then C<'production'>.

If the connection parameters for the requested environment are not available,
the method returns nothing, which can be used with C<or die...>:

  my @params = $config->connectionParameters or die "no parameters!";
  my $dbh = DBI->connect(@params) || die $DBI::errstr;

A special top-level section named 'defaults' will be set as the defaults for
all other environments.

=item connect

=item connect(environment)

Returns a DBI database handle (C<$dbh>) connected to the specified (or
default) environment.

=back

=head1 AUTHOR

Philip Garrett, E<lt>philip.garrett@icainformatics.comE<gt>

=head1 COPYRIGHT & LICENSE

Copyright (c) 2014 by ICA. All rights reserved.

=cut
