package StackIt::DB;

use Moose;
use StackIt::Moose::Types;

# Database Handle
has 'DBH' => ( is => 'rw', isa => 'DBI', required => 1 );

# Public Methods

sub doTransaction {
  my ($self,$code) = @_;
  my $dbh = $self->DBH;
  local $dbh->{AutoCommit} = 0;
  local $dbh->{RaiseError} = 0;
  eval {
    &$code();
    $dbh->commit;
  };
  my $err = $@;
  if ($err) {
    eval { $dbh->rollback };
    if ($@) {
      $err .= " (could not roll back: $@)";
    }
    else {
      $err .= " (transaction rolled back)";
    }
    die $err;
  }
}

# Private Methods

no Moose;

1;
