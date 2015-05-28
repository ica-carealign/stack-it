package StackIt::Env;
use strict;
use warnings;

sub ConfigDirectory {
  return $ENV{STACKIT_CONF} || '/etc/stack-it';
}

sub Environment {
  return $ENV{STACKIT_ENV} || 'production';
}

1;

=head1 NAME

StackIt::Env - Environment details for StackIt

=head1 SYNOPSIS

  use StackIt::Env;

  # uses $ENV{STACKIT_CONF}, default '/etc/stack-it'
  my $config_directory = StackIt::Env->ConfigDirectory;
  open(my $CFG, "<", "$config_directory/some_file.config") || die $!;

  # uses $ENV{STACKIT_ENV}, default 'production'
  printf "StackIt is running in %s mode\n", StackIt::Env->Environment;

=head1 DESCRIPTION

This module provides access to the StackIt runtime environment variables.
Defaults are provided where applicable.

All methods are class (static) methods.

=head2 METHODS

=item Environment

Returns the type of environment currently in use e.g. development or
production.

Returns the contents of the C<STACKIT_ENV> environment variable. The default
is 'production'.

Besides 'production', the environment names are arbitrary. Recommended
values are 'production', 'staging', 'qa', and 'development'.

=item ConfigDirectory

Returns the directory containing the StackIt configuration files. You can
influence this by setting C<STACKIT_CONF> environment variable. The default is
C</etc/stack-it>.

=head1 AUTHOR

Philip Garrett, E<lt>philip.garrett@icainformatics.comE<gt>

=head1 COPYRIGHT & LICENSE

Copyright (c) 2014 by ICA. All rights reserved.

=cut
