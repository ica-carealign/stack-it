package StackIt::View::JSON;

use strict;
use base 'Catalyst::View::JSON';

use JSON::XS qw();

our $encoder = JSON::XS->new->utf8->pretty->allow_nonref;

sub encode_json {
  my ($self,$c,$data) = @_;
  return $encoder->encode($data);
}

=head1 NAME

StackIt::View::JSON - Catalyst JSON View

=head1 SYNOPSIS

See L<StackIt>

=head1 DESCRIPTION

Catalyst JSON View.

=head1 AUTHOR

A clever guy

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
