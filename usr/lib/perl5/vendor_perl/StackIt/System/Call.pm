package StackIt::System::Call;

use Moose;
use StackIt::Moose::Types;

extends 'StackIt::Object';

# String Properties
has 'Command'     => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'ExitMessage' => ( is => 'ro', isa => 'CleanStr', default => '' );
has 'Output'      => ( is => 'ro', isa => 'CleanStr', default => '' );

# Integer Properties
has 'ExitCode'    => ( is => 'ro', isa => 'Int', default => 0  );

# Boolean Properties
has 'GetOutput'   => ( is => 'rw', isa => 'Bool', default => 0 );

# Public Methods
sub execute {
  my ($self) = @_;

  #local $SIG{'CHLD'} = "DEFAULT";

  return 0 unless($self->Command);

  $self->Log->debug('EXECUTE:  ' . $self->Command);

  if($self->GetOutput) {
    my $command = $self->Command;
    $self->{'Output'} = `$command`;
    $self->{'ExitCode'} = $? >> 8;

    if($self->ExitCode) {
      $self->Log->error('OUTPUT:  ' . $self->Output);
    } else {
      $self->Log->debug('OUTPUT:  ' . $self->Output);
    }
  } else {
    $self->{'ExitCode'} = system($self->Command) >> 8;
    $self->Log->error('An unknown error has occured!') if($self->ExitCode);
  }
}

# Private Methods

no Moose;

1;
