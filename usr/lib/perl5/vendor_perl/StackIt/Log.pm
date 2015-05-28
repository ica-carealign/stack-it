package StackIt::Log;

use Moose;

# List Properties
has 'Debug'    => ( is => 'ro', isa => 'ArrayRef', default => sub { [] } );
has 'Info'     => ( is => 'ro', isa => 'ArrayRef', default => sub { [] } );
has 'Errors'   => ( is => 'ro', isa => 'ArrayRef', default => sub { [] } );
has 'Warnings' => ( is => 'ro', isa => 'ArrayRef', default => sub { [] } );

# Public Methods
sub lastError {
  my ($self) = @_;
  my ($last);

  return undef unless(@{$self->Errors});

  $last = $self->Errors->[$#{$self->Errors}];
  $last =~ s/'//g;

  return $last;
}

sub lastWarning {
  my ($self) = @_;
  my ($last);

  return undef unless(@{$self->Warnings});

  $last = $self->Warnings->[$#{$self->Warnings}];
  $last =~ s/'//g;

  return $last;
}

sub error {
  my ($self, $msg) = @_;
  push @{$self->{Errors}}, $msg;
}

sub warning {
  my ($self, $msg) = @_;
  push @{$self->{Warnings}}, $msg;
}

sub info {
  my ($self, $msg) = @_;
  push @{$self->{Info}}, $msg;
}

sub debug {
  my ($self, $msg) = @_;
  push @{$self->{Debug}}, $msg;
}

sub print {
  my ($self, $levels) = @_;

  foreach my $level (@{$levels}) {
    foreach my $message (@{$self->$level}) {
      print STDERR "[$level] $message\n";
    }
  }
}

no Moose;

1;
