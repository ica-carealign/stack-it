package StackIt::EC2::HostName;

use Moose;
use StackIt::Moose::Types;

extends 'StackIt::Object';

# String Properties
has 'InstanceName' => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'RootZone'     => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'StackName'    => ( is => 'rw', isa => 'CleanStr', default => '' );

sub Domain {
  my ($self) = @_;
  my $domain = '';

  if($self->StackName && $self->RootZone) {
    $domain = lc join(".", $self->StackName, $self->RootZone);  
  }
 
  return $domain;
}

sub HostName {
  my ($self) =  @_;
  my $hostname = '';

  if($self->InstanceName) {
    # The instance name submitted from the web form includes the stack name.
    # Remove it so this hostname becomes:
    #  auidb0.happyhermit.example.com
    # Instead of:
    #  HAPPYHERMITAUIDB0.HappyHermit.example.com
    my $stack_name_pattern = quotemeta($self->StackName || '');

    $hostname = $self->InstanceName;
    $hostname =~ s/^$stack_name_pattern//i;
  }
  
  return lc $hostname;
}

sub FQDN {
  my ($self) =  @_;
  my $fqdn = '';
  
  if($self->HostName) {
    if($self->Domain) {
      $fqdn = $self->HostName . '.' . $self->Domain;
    } else {
      $fqdn = $self->HostName;
    }
  }

  return $fqdn;
}

# Public Methods

no Moose;

1;
