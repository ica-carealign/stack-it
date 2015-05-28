#!/usr/bin/env perl
# IMPORTANT: if you delete this file your app will not work as
# expected.  You have been warned.
use inc::Module::Install;
use Module::Install::Catalyst; # Complain loudly if you don't have
                               # Catalyst::Devel installed or haven't said
                               # 'make dist' to create a standalone tarball.

name 'StackIt';
all_from 'lib/StackIt.pm';

requires 'Cache::Memcached';
requires 'Catalyst::Action::RenderView';
requires 'Catalyst::Plugin::Cache';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::StackTrace';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Runtime' => '5.90006';
requires 'Catalyst::View::JSON';
requires 'Catalyst::View::TT';
requires 'Config::General';
requires 'Date::Parse';
requires 'JSON::XS';
requires 'Moose';
requires 'namespace::autoclean';
requires 'YAML::Tiny';
requires 'DBI';
requires 'DBD::mysql';

test_requires 'Test::More' => '0.88';
catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
