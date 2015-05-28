package StackIt::Collection::Role;

use Moose;
use JSON::XS;
use StackIt::Moose::Types;
use StackIt::Definition::Role;
use StackIt::Definition::Role::Port;
use StackIt::Definition::Role::Port::DNSRecord;
use StackIt::Definition::Role::Dependency;

extends 'StackIt::Collection';

# String Properties
has 'JSONDir'    => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'UML'        => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'WikiMarkUp' => ( is => 'rw', isa => 'CleanStr', default => '' );

# Public Methods
sub populate {
  my ($self, $jsonDir) = @_;

  $jsonDir = $self->JSONDir if($self->JSONDir);
  return 1 unless($jsonDir);

  return 1 unless(opendir(DIR, $jsonDir));
  my @files = grep { /\.json$/ } readdir DIR;
  closedir(DIR);

  foreach my $file (@files) {
    my $decodedJSON = '';

    open(FH, $jsonDir . '/' . $file) || die "Cannot open $file";
    local $/;
    $decodedJSON = decode_json(<FH>);
    close(FH);

    # Add role to roles collection
    my $roleObj = new StackIt::Definition::Role();

    $roleObj->Role($decodedJSON->{'role'});

    if($decodedJSON->{'environment'}) {
      $roleObj->Environment($decodedJSON->{'environment'});
    }

    foreach my $port (@{$decodedJSON->{'ports'}}) {
      my $portObj = new StackIt::Definition::Role::Port();

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
        foreach my $dnsRecord (@{$port->{'dnsRecords'}}) {
          my $dnsRecord = new StackIt::Definition::Role::Port::DNSRecord();
          $dnsRecord->Type($dnsRecord->{'type'});
          $dnsRecord->Name($dnsRecord->{'name'});
          $dnsRecord->TTL($dnsRecord->{'ttl'});
          $portObj->addDNSRecord($dnsRecord);
        }
      }
    }

    foreach my $dependency (@{$decodedJSON->{'dependencies'}}) {
      my $role = (keys %{$dependency})[0];

      foreach my $port (@{$dependency->{$role}}) {
        my $dependencyObj = new StackIt::Definition::Role::Dependency();
      
        $dependencyObj->Role($role);
        $dependencyObj->Port($port);
      
        $roleObj->addDependency($dependencyObj);
      }
    }

    $self->addMember($roleObj);
  }

  return 0;
}

sub generateUML {
  my ($self)       = @_;
  my %interfaces   = ();
  my @dependencies = ();

  # Build a hash of all interfaces from each role.  Each interface
  # will be indexed with a temporary value ('I1','I2',etc)
  my $i = 0;

  foreach my $role (@{$self->Collection}) {
    foreach my $port (@{$role->Ports}) {
      # Key is ROLE:PORT
      # Value is I#
      $interfaces{$role->Role . ':' . $port->Port} = 'I' . $i;
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
      # Point our role at the dependency
      if(exists $interfaces{$dependency->Role . ':' . $dependency->Port}) {
        my $interface = $interfaces{$dependency->Role . ':' . $dependency->Port};
        push @dependencies, '[' . $role->Role . '] --> ' . $interface;
      }
    }

    $self->{'UML'} .= '}' . "\n";
  }

  # Loop over the dependencies and print each one. These need to come
  # at the end of the file, after all of the interfaces are defined
  foreach my $dependency (@dependencies) {
    $self->{'UML'} .= $dependency . "\n";
  }
}

sub generateWikiMarkUp {
  my ($self) = @_;

  $self->generateUML() unless($self->UML);

  $self->{'WikiMarkUp'} .= '{plantuml}' . "\n";;
  $self->{'WikiMarkUp'} .= $self->UML;
  $self->{'WikiMarkUp'} .= '{plantuml}' . "\n";
}

no Moose;

1;
