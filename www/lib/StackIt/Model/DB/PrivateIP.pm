package StackIt::Model::DB::PrivateIP;

use Moose;

use StackIt::DB::PrivateIP;

extends 'StackIt::Model::Utils';

# Public Methods
sub get {
  my ($self, $subnet) = @_;
  my $ip = new StackIt::DB::PrivateIP('DBH' => $self->DBH);

  $ip->getFirstInactiveIP();
  $ip->generateNewIP($subnet) unless($ip->PrivateIP);

  $self->_logMessages($ip);

  return $ip;
}

no Moose;

1;
