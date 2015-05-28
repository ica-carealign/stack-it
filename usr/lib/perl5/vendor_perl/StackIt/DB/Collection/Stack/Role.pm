package StackIt::DB::Collection::Stack::Role;

use Moose;
use JSON::XS;
use StackIt::Moose::Types;
use StackIt::DB::Stack::Role;
use StackIt::DB::Port;
use StackIt::DB::Dependency;
use StackIt::DB::DNSRecord;

extends 'StackIt::Collection', 'StackIt::DB';

# String Properties
has 'Environment' => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'JSONDir'     => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'UML'         => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'WikiMarkUp'  => ( is => 'rw', isa => 'CleanStr', default => '' );

# Public Methods
sub populateFromDB {
  my ($self) = @_;
  my ($sql, $sth, @parameters);

  if($self->Environment) {
    $sql = 'SELECT `id` FROM `role` WHERE `environment` = ?';
    push @parameters, $self->Environment;
  } else {
    $sql = 'SELECT `id` FROM `role`';
  }

  $sth = $self->DBH->prepare($sql);

  unless($sth) {
    $self->Log->error($self->DBH->errstr);
    return 1;
  }

  $sth->execute(@parameters);

  if($sth->errstr) {
    $self->Log->error($sth->errstr);
    return 1;
  }

  while(my $record = $sth->fetchrow_hashref()) {
    my $roleObj = new StackIt::DB::Stack::Role('DBH' => $self->DBH);
    $roleObj->ID($record->{'id'});
    $self->addMember($roleObj);
  }

  $sth->finish() if($sth);
}

sub populateFromJSON {
  my ($self, $jsonDir) = @_;

  $jsonDir = $self->JSONDir if($self->JSONDir);
  return 1 unless($jsonDir);

  return 1 unless(opendir(DIR, $jsonDir));
  my @files = grep { /\.json$/ } readdir DIR;
  closedir(DIR);

  foreach my $file (@files) {
    my ($decodedJSON);

    open(FH, $jsonDir . '/' . $file) || die "Cannot open $file";
    local $/;
    $decodedJSON = decode_json(<FH>);
    close(FH);

    $decodedJSON = $self->setJSONDefaults($decodedJSON);

    if($self->Environment) {
      next unless($decodedJSON->{'environment'} eq $self->Environment);
    }

    # Add role to roles collection
    my $roleObj = new StackIt::DB::Stack::Role('DBH' => $self->DBH);

    $roleObj->Role($decodedJSON->{'role'});
    $roleObj->Version($decodedJSON->{'version'});
    $roleObj->OS($decodedJSON->{'os'});
    $roleObj->Environment($decodedJSON->{'environment'});
    $roleObj->NumberOfInstances($decodedJSON->{'instances'});
    $roleObj->Description($decodedJSON->{'description'});

    foreach my $port (@{$decodedJSON->{'ports'}}) {
      my $portObj = new StackIt::DB::Port('DBH' => $self->DBH);

      $portObj->Provides($port->{'provides'});
      $portObj->Port($port->{'port'});
      $portObj->TCP($port->{'tcp'} ? 1 : 0);
      $portObj->UDP($port->{'udp'} ? 1 : 0);
      $portObj->External($port->{'external'} ? 1 : 0);
      $portObj->Inbound($port->{'inbound'} ? 1 : 0);
      $portObj->Outbound($port->{'outbound'} ? 1 : 0);
      $portObj->Clusterable($port->{'clusterable'} ? 1 : 0);
      $portObj->Use($port->{'use'});

      $roleObj->addPort($portObj);

      if ($port->{'dnsRecords'}) {
        for my $dnsRecord (@{$port->{'dnsRecords'}}) {
          my $dnsRecordObj = new StackIt::DB::DNSRecord(DBH => $self->DBH);
          $dnsRecordObj->Type($dnsRecord->{'type'});
          $dnsRecordObj->Name($dnsRecord->{'name'});
          $dnsRecordObj->TTL($dnsRecord->{'ttl'});
          $portObj->addDNSRecord($dnsRecordObj);
        }
      }
    }

    foreach my $dependency (@{$decodedJSON->{'dependencies'}}) {
      my $dependencyObj = new StackIt::DB::Dependency('DBH' => $self->DBH);
      
      $dependencyObj->Dependency($dependency);
      
      $roleObj->addDependency($dependencyObj);
    }

    $self->addMember($roleObj);
  }

  return 0;
}

sub generateUML {
  my ($self)       = @_;
  my %interfaces   = ();
  my %provides     = ();
  my @dependencies = ();

  # We generate UML based on environment...
  unless($self->Environment) {
    $self->Log->error('Cannot generate UML:  Environment undefined');
    return 1;
  }

  # Build a hash of all interfaces from each role.  Each interface
  # will be indexed with a temporary value ('I1','I2',etc)
  my $i = 0;

  foreach my $role (@{$self->Collection}) {
    foreach my $port (@{$role->Ports}) {
      # Key is ROLE:PORT
      # Value is I#
      $interfaces{$role->Role . ':' . $port->Port} = 'I' . $i;
      $provides{$port->Provides} = $role->Role . ':' . $port->Port;
      $i++;
    }
  }

  # Build the nodes.  Nodes contain interfaces (ports)
  foreach my $role (@{$self->Collection}) {
    # Create one node per role
    $self->{'UML'} .= 'node "' . $role->Role . '" {' . "\n";

    foreach my $port (@{$role->Ports}) {
      # Create one interface for each port
      my $interface = $interfaces{$role->Role . ':' . $port->Port};

      $self->{'UML'} .= 'interface "' . $port->Port . '" as ' . $interface;
      $self->{'UML'} .= "\n";
    }

    $self->{'UML'} .= '[' . $role->Role . ']' . "\n";

    foreach my $dependency (@{$role->Dependencies}) {
      if(exists $provides{$dependency->Dependency}) {
        # Point our role at the dependency
        if(exists $interfaces{$provides{$dependency->Dependency}}) {
          my $interface = $interfaces{$provides{$dependency->Dependency}};
          push @dependencies, '[' . $role->Role . '] --> ' . $interface;
        }
      } else {
        # TODO: This needs to be tested and reported on by the database engine 
        # through foreign key enforcement...
        $self->Log->warning('Dependency ' . $dependency->Dependency . ' not defined');
      }
    }

    $self->{'UML'} .= '}' . "\n";
  }

  # Loop over the dependencies and print each one. These need to come
  # at the end of the file, after all of the interfaces are defined
  foreach my $dependency (@dependencies) {
    $self->{'UML'} .= $dependency . "\n";
  }

  return 0;
}

sub setJSONDefaults {
  my ($self, $json) = @_;

  $json->{'role'}         = '' unless(exists $json->{'role'});
  $json->{'environment'}  = '' unless(exists $json->{'environment'});
  $json->{'ports'}        = [] unless(exists $json->{'ports'});
  $json->{'dependencies'} = [] unless(exists $json->{'dependencies'});

  return $json;
}

sub generateWikiMarkUp {
  my ($self) = @_;

  $self->generateUML() unless($self->UML);

  $self->{'WikiMarkUp'} .= '{plantuml}' . "\n";;
  $self->{'WikiMarkUp'} .= $self->UML;
  $self->{'WikiMarkUp'} .= '{plantuml}' . "\n";
}

sub save {
  my ($self) = @_;

  unless($self->DBH) {
    $self->_errstr('Database handle undefined');
    return 1;
  }

  foreach my $role (@{$self->Collection}) {
    $role->save();
  }

  return 0;
}

no Moose;

1;
