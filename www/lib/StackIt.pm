package StackIt;

use Moose;
use namespace::autoclean;

use Catalyst::Runtime 5.80;

# Set flags and add plugins for the application.
#
# Note that ORDERING IS IMPORTANT here as plugins are initialized in order,
# therefore you almost certainly want to keep ConfigLoader at the head of the
# list if you're using it.
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

no warnings 'qw';

use Catalyst qw/
    ConfigLoader
    Static::Simple
    StackTrace
    Cache
    +Data::Dumper
    -Log=debug,info,warn,fatal,error
/;

extends 'Catalyst';

our $VERSION = 'v0.2.3';

# Configure the application.
#
# Note that settings in stackit.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with an external configuration file acting as an override for
# local deployment.

__PACKAGE__->config(
  name => 'StackIt',
  # Disable deprecated behavior needed by old applications
  disable_component_resolution_regex_fallback => 1,
  'View::HTML' => {
    'INCLUDE_PATH' => [
      __PACKAGE__->path_to( 'root', 'templates' ),
      __PACKAGE__->path_to( 'root', 'static', 'script_log' )
    ],
    'WRAPPER' => 'wrapper.tt',
    'ABSOLUTE' => 1
  },
  'View::JSON' => {
    'expose_stash' => [ qw/json/ ]
  },
  'Plugin::Cache' => {
    backend => {
      class => 'Cache::Memcached',
      namespace => 'stackit',
      servers => [ 'localhost:11211' ]
    }
  }
);

# Start the application
__PACKAGE__->setup();

=head1 NAME

StackIt - Catalyst based application

=head1 SYNOPSIS

    script/stackit_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<StackIt::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Catalyst developer

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
