package StackIt::Model::EC2;

use Moose;
use StackIt::DB::Collection::Instance;
use StackIt::Collection::CFN::Resource;
use StackIt::Collection::EC2::Instance;
use StackIt::AWS::EC2::Stop;
use StackIt::AWS::EC2::Start;
use POSIX;

extends 'StackIt::Model::Utils';

# Public Methods
sub listInstances {
  my ($self, $c) = @_;
  my $stack_name = $c->request->parameters->{'StackName'};
  my $cache_name = $stack_name . '-instance-list';

  # Initialize memcached with an empty data set...
  unless($c->cache->get($cache_name)) {
    $self->_refreshInstanceList(
      $c->cache,
      $cache_name,
      $stack_name,
      $c->config->{'instance_list_cache_expire'},
      $c->config->{'aws_region'},
      $c->config->{'aws_access_key'},
      $c->config->{'aws_secret_key'},
      $c->config->{'aws_region'},
      $c->config->{'root_zone'},
      $c->model('DB')->dbh,
      $c->config->{'status_time_out'}
    );
  }

  # Schedule a job to update the cached value...
  $c->cache->set(
    '-job-refresh-' . $cache_name,
    {
      'StackIt::Job::Cache::InstanceList' => {
        'StackName'      => $stack_name,
        'CacheTTL'       => $c->config->{'instance_list_cache_expire'},
        'AWSAccessKeyId' => $c->config->{'aws_access_key'},
        'SecretKey'      => $c->config->{'aws_secret_key'},
        'Region'         => $c->config->{'aws_region'},
        'RootZone'       => $c->config->{'root_zone'},
        'StatusTimeOut'  => $c->config->{'status_time_out'}
      }
    }
  );

  return $c->cache->get($cache_name);
}

sub stopInstance {
  my ($self, $c) = @_;
  my $request = new StackIt::AWS::EC2::Stop();

  $request->AWSAccessKeyId($c->config->{'aws_access_key'});
  $request->SecretKey($c->config->{'aws_secret_key'});
  $request->Region($c->config->{'aws_region'});
  $request->InstanceId([$c->request->parameters->{'InstanceID'}]);

  $request->post();

  $self->_logMessages($request);

  return $request->StatusCode == 200 ? 0 : $request->StatusCode;
}

sub startInstance {
  my ($self, $c) = @_;
  my $request = new StackIt::AWS::EC2::Start();

  $request->AWSAccessKeyId($c->config->{'aws_access_key'});
  $request->SecretKey($c->config->{'aws_secret_key'});
  $request->Region($c->config->{'aws_region'});
  $request->InstanceId([$c->request->parameters->{'InstanceID'}]);

  $request->post();

  $self->_logMessages($request);

  return $request->StatusCode == 200 ? 0 : $request->StatusCode;
}

# Private Function
sub _refreshInstanceList {
  my ( $self,
       $cache,
       $cache_name,
       $stack_name,
       $cache_expire,
       $aws_region,
       $access_key,
       $secret_key,
       $region,
       $root_zone,
       $dbh,
       $status_timeout ) = @_;

  unless($cache->get($cache_name)) {
    my $resources = new StackIt::Collection::CFN::Resource();

    $resources->StackName($stack_name);
    $resources->AWSAccessKeyId($access_key);
    $resources->SecretKey($secret_key);
    $resources->Region($region);

    $resources->populate();

    my $instance_ids = [];

    foreach my $resource (@{$resources->Collection}) {
      if($resource->Type eq 'AWS::EC2::Instance') {
        push @{$instance_ids}, $resource->PhysicalID;
      }
    }

    my $instances = new StackIt::Collection::EC2::Instance();

    $instances->InstanceIDs($instance_ids);
    $instances->StackName($stack_name);
    $instances->AWSAccessKeyId($access_key);
    $instances->SecretKey($secret_key);
    $instances->Region($region);
    $instances->RootZone($root_zone);

    $instances->populate();

    # TODO:  This is not a good way to merge these two collections...
    my $db_instances = new StackIt::DB::Collection::Instance(
      'DBH'           => $dbh,
      'StackName'     => $stack_name,
      'StatusTimeOut' => $status_timeout
    );

    foreach my $instance (@{$instances->Collection}) {
      if($instance->PrivateIP) {
        my @octets = split(/\./, $instance->PrivateIP);

        foreach my $db_instance (@{$db_instances->Collection}) {
          if($db_instance->PrivateIPID eq $octets[3]) {
            $instance->BuildStatus($db_instance->BuildStatus);
            last;
          }
        }
      }
    }

    $cache->set(
      $cache_name,
      $instances->toHash(),
      $cache_expire
    );
  }
}

no Moose;

1;
