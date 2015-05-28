package StackIt::Model::CFN;

use Moose;
use JSON;
use POSIX;

use StackIt::Time;
use StackIt::Collection::CFN::List;
use StackIt::Collection::CFN::Event;
use StackIt::AWS::CFN::Delete;
use StackIt::AWS::CFN::Create;
use StackIt::System::Call::Puppet::Clean;
use StackIt::EC2::HostName;

use StackIt::CFN::Template::SecurityGroup;
use StackIt::CFN::Template::Instance;
use StackIt::CFN::Template::WaitCondition;
use StackIt::CFN::Template::WaitHandler;
use StackIt::CFN::Template::Output;
use StackIt::CFN::Template::RT53;
use StackIt::CloudFormation;

extends 'StackIt::Model::Utils';

# Public Methods
sub listStacks {
  my ($self, $c) = @_;

  # Initialize memcached... 
  unless($c->cache->get('stack-list')) {
    $self->_refreshStackList(
      $c->cache,
      $c->config->{'stack_list_cache_expire'},
      $c->config->{'aws_access_key'},
      $c->config->{'aws_secret_key'},
      $c->config->{'aws_region'},
      $c->model('DB')->dbh,
      $c->config->{'status_time_out'}
    );
  }

  # Schedule a job to update the cached value...
  $c->cache->set(
    '-job-refresh-stack-list',
    {
      'StackIt::Job::Cache::Stack::List' => {
        'CacheTTL'       => $c->config->{'stack_list_cache_expire'},
        'AWSAccessKeyId' => $c->config->{'aws_access_key'}, 
        'SecretKey'      => $c->config->{'aws_secret_key'},
        'Region'         => $c->config->{'aws_region'},
        'StatusTimeOut'  => $c->config->{'status_time_out'}
      }
    }
  );

  return $c->cache->get('stack-list');
}

sub listEvents {
  my ( $self, $c ) = @_;

  my $collection = new StackIt::Collection::CFN::Event();

  $collection->AWSAccessKeyId($c->config->{'aws_access_key'});
  $collection->SecretKey($c->config->{'aws_secret_key'});
  $collection->Region($c->config->{'aws_region'});
  $collection->StackName($c->request->parameters->{'StackName'});

  $collection->populate();

  return $collection->toHash();
}

sub createStack {
  my ($self, $c) = @_;
  my $errors = 0;

  my $cfn = new StackIt::CloudFormation();

  $cfn->TemplatePath($c->config->{'template_path'});
  $cfn->StackName($c->request->parameters->{'StackName'});
  $cfn->OutputDir($c->config->{'tmp_cfn_dir'});
  $cfn->Description($c->request->parameters->{'StackDescription'});

  my $instances = decode_json($c->request->parameters->{'Instances'});

  foreach my $instanceInput (@{$instances}) {
    my ($ipObj, $scheduleObj);

    $instanceInput = decode_json($instanceInput);

    # Instantiate and add a wait handler template object...
    $cfn->addResource($self->_instantiateSecurityGroupTpl($c, $instanceInput, $cfn));

    # Instantiate and add an instance template object...
    $c->model('DB')->PrivateIP->DBH($c->model('DB')->dbh);
    $c->model('DB')->Schedule->DBH($c->model('DB')->dbh);

    $ipObj = $c->model('DB')->PrivateIP->get($c->config->{'instance_subnet'});
    $scheduleObj = $c->model('DB')->Schedule->get($instanceInput->{'ScheduleID'});

    $cfn->addResource($self->_instantiateInstanceTpl($c, $instanceInput, $cfn, $ipObj, $scheduleObj));

    # Instantiate and add a wait handler template object...
    $cfn->addResource($self->_instantiateWaitHandlerTpl($c, $instanceInput, $cfn));

    # Instantiate and add a wait condition template object...
    $cfn->addResource($self->_instantiateWaitConditionTpl($c, $instanceInput, $cfn));

    # Instantiate and add a Route53 template object for the main instance name...
    $cfn->addResource($self->_instantiateRT53Tpl($c, $instanceInput, $cfn));

    # Instantiate and add a Route53 object for each DNS record defined in the
    # role's ports definitions.
    for my $tpl ($self->_instantiateDnsRecordRT53Tpls($c, $instanceInput, $cfn)) {
      $cfn->addResource($tpl);
    }

    $c->model('DB')->Instance->DBH($c->model('DB')->dbh);
    $errors += $c->model('DB')->Instance->save(
      $c->request->parameters->{'StackName'},
      $instanceInput,
      $ipObj
    );
  }

  $cfn->NoOutput(1);
  $cfn->outputTemplate();

  my $request = new StackIt::AWS::CFN::Create();

  $request->StackName($c->request->parameters->{'StackName'});
  $request->TemplateFilePath($c->config->{'tmp_cfn_dir'} . '/' . $cfn->CFNTemplate);
  $request->AWSAccessKeyId($c->config->{'aws_access_key'});
  $request->SecretKey($c->config->{'aws_secret_key'});
  $request->Region($c->config->{'aws_region'});
  $request->BucketName($c->config->{'s3_template_bucket'});
  $request->DisableRollback(1);

  $request->uploadTemplateToS3();
  $request->post();

  $self->_logMessages($request);
  $errors += $request->StatusCode == 200 ? 0 : $request->StatusCode;

  return $errors;
}

sub deleteStack {
  my ($self, $c) = @_;
  my $stack_name = $c->request->parameters->{'StackName'};
  my $cache_name = '-job-' . $stack_name . '-stack-delete';

  unless($c->cache->get($cache_name)) {
    $c->cache->set(
      $cache_name,
      {
        'StackIt::Job::Cache::Stack::Delete' =>
        {
          'StackName'      => $c->request->parameters->{'StackName'},
          'AWSAccessKeyId' => $c->config->{'aws_access_key'},
          'SecretKey'      => $c->config->{'aws_secret_key'},
          'Region'         => $c->config->{'aws_region'},
          'RootZone'       => $c->config->{'root_zone'},
          'CleanPuppet'    => $c->config->{'enable_puppet_clean_up'}
        }
      }
    );
  }

  return 0;
}

sub deleteTCStacks {
  my ($self, $c) = @_;

  my $stacks = $self->listStacks($c);

  foreach my $stack (@{$stacks->{'Collection'}}) {
    if($stack->{'StackName'} =~ m/^Testing\d{14}$/) {
      $c->request->parameters->{'StackName'} = $stack->{'StackName'};
      $self->deleteStack($c);
    }
  }

  return 0;
}

sub stopStack {
  my ($self, $c) = @_;
  my $stack_name = $c->request->parameters->{'StackName'};
  my $cache_name = '-job-' . $stack_name . '-stack-stop';

  unless($c->cache->get($cache_name)) {
    $c->cache->set(
      $cache_name,
      {
        'StackIt::Job::Cache::Stack::Stop' =>
        {
          'StackName'      => $c->request->parameters->{'StackName'},
          'AWSAccessKeyId' => $c->config->{'aws_access_key'},
          'SecretKey'      => $c->config->{'aws_secret_key'},
          'Region'         => $c->config->{'aws_region'}
        }
      }
    );
  }

  return 0;
}

sub startStack {
  my ($self, $c) = @_;
  my $stack_name = $c->request->parameters->{'StackName'};
  my $cache_name = '-job-' . $stack_name . '-stack-start';

  unless($c->cache->get($cache_name)) {
    $c->cache->set(
      $cache_name,
      {
        'StackIt::Job::Cache::Stack::Start' =>
        {
          'StackName'      => $c->request->parameters->{'StackName'},
          'AWSAccessKeyId' => $c->config->{'aws_access_key'},
          'SecretKey'      => $c->config->{'aws_secret_key'},
          'Region'         => $c->config->{'aws_region'}
        }
      }
    );
  }

  return 0;
}

# Private Methods
sub _refreshStackList {
  my ( $self,
       $cache,
       $cache_expire,
       $access_key,
       $secret_key,
       $region,
       $dbh,
       $status_timeout ) = @_;

  my $collection = new StackIt::Collection::CFN::List(DBH => $dbh);

  $collection->AWSAccessKeyId($access_key);
  $collection->SecretKey($secret_key);
  $collection->Region($region);
  $collection->StatusTimeOut($status_timeout);

  $collection->populate();

  $cache->set(
    'stack-list',
    $collection->toHash(),
    $cache_expire
  );
}

sub _instantiateInstanceTpl {
  my ($self, $c, $instanceInput, $stackTemplate, $ipObj, $scheduleObj) = @_;
  my $instance = new StackIt::CFN::Template::Instance();
  my $hostname = new StackIt::EC2::HostName();

  $hostname->InstanceName($instanceInput->{'InstanceName'});
  $hostname->RootZone($c->config->{'root_zone'});
  $hostname->StackName($stackTemplate->StackName);

  if($instanceInput->{'ImageID'} =~ m/^centos/) {
    $instance->isLinux(1);

    if($instanceInput->{'ImageID'} =~ m/6/) {
      $instance->VolumeDevice('/dev/xvda');
    }
  } else {
    $instance->isLinux(0);
  }

  $instance->ImageID($c->config->{$instanceInput->{'ImageID'}});
  $instance->Role($instanceInput->{'Role'});
  $instance->Version($instanceInput->{'Version'});
  $instance->Environment($instanceInput->{'Environment'});
  $instance->Name($instanceInput->{'InstanceName'});
  $instance->Tags({ 'Name' => $instanceInput->{'InstanceName'} });

  $instance->KeyName($instanceInput->{'KeyName'});
  $instance->PuppetMaster($c->config->{'puppet_master'});
  $instance->ArtifactServer($c->config->{'artifact_server'});
  $instance->SubnetID($c->config->{'instance_subnet_id'});
  $instance->InstanceType($instanceInput->{'InstanceType'});
  $instance->SecurityGroupID($c->config->{'stackit_security_group_id'});
  $instance->SecurityGroupRef($instanceInput->{'InstanceName'} . 'SG');
  $instance->TemplatePath($c->config->{'template_path'});
  $instance->WaitHandler($instanceInput->{'InstanceName'} . 'WH');
  $instance->HostName($hostname->HostName);
  $instance->Domain($hostname->Domain);
  $instance->InstanceName($instanceInput->{'InstanceName'});

  if($instanceInput->{'VolumeType'}) {
    $instance->VolumeType($instanceInput->{'VolumeType'});
  }

  if($instanceInput->{'VolumeSize'} =~ m/^\d+$/) {
    $instance->VolumeSize($instanceInput->{'VolumeSize'});
  }

  if($ipObj->PrivateIP) {
    $instance->PrivateIP($ipObj->PrivateIP);
  } else {
    $c->log->error('Could not assign Private IP address.');
  }

  if($instanceInput->{'ScheduleID'}) {
    $instance->Tags->{'schedule'} = $scheduleObj->serialize(1, 1);
  }

  if($hostname->FQDN && $hostname->RootZone) {
    $instance->Tags->{'dns'} = join(
      '|',
      $hostname->FQDN,
      $hostname->RootZone
    );
  }

  if($instanceInput->{'Role'} eq 'PUPPET_MASTER') {
    $instance->SkipPuppet(1);
  }

  return $instance;
}

sub _instantiateWaitHandlerTpl {
  my ($self, $c, $instanceInput, $stackTemplate) = @_;
  my $waitHandler = new StackIt::CFN::Template::WaitHandler();

  $waitHandler->Name($instanceInput->{'InstanceName'} . 'WH');
  $waitHandler->TemplatePath($c->config->{'template_path'});

  return $waitHandler;
}

sub _instantiateWaitConditionTpl {
  my ($self, $c, $instanceInput, $stackTemplate) = @_;
  my $waitCondition = new StackIt::CFN::Template::WaitCondition();

  $waitCondition->Name($instanceInput->{'InstanceName'} . 'WC');
  $waitCondition->TemplatePath($c->config->{'template_path'});
  $waitCondition->Instance($instanceInput->{'InstanceName'});
  $waitCondition->WaitHandler($instanceInput->{'InstanceName'} . 'WH');
  $waitCondition->Timeout($c->config->{'aws_wait_condition_time_out'});

  return $waitCondition;
}

sub _instantiateSecurityGroupTpl {
  my ($self, $c, $instanceInput, $stackTemplate) = @_;
  my ($roleID, $securityGroup, $ports);

  $c->model('DB')->Role->DBH($c->model('DB')->dbh);
  $c->model('DB')->Port->DBH($c->model('DB')->dbh);

  $roleID = $c->model('DB')->Role->getID({
    'Role'        => $instanceInput->{'Role'},
    'Environment' => $instanceInput->{'Environment'}
  });

  $ports = $c->model('DB')->Port->list({
    'RoleID' => $roleID
  });

  $securityGroup = new StackIt::CFN::Template::SecurityGroup();

  $securityGroup->Name($instanceInput->{'InstanceName'} . 'SG');
  $securityGroup->TemplatePath($c->config->{'template_path'});
  $securityGroup->Description($instanceInput->{'InstanceName'});
  $securityGroup->VpcID($c->config->{'instance_vpc_id'});
  $securityGroup->Subnet($c->config->{'instance_subnet'});

  $securityGroup->Ports($ports->{'Collection'});

  return $securityGroup;
}

sub _instantiateRT53Tpl {
  my ($self, $c, $instanceInput, $stackTemplate) = @_;
  my $rt53 = new StackIt::CFN::Template::RT53();
  my $hostname = new StackIt::EC2::HostName();

  $hostname->InstanceName($instanceInput->{'InstanceName'});
  $hostname->RootZone($c->config->{'root_zone'});
  $hostname->StackName($stackTemplate->StackName);

  $rt53->Name($instanceInput->{'InstanceName'} . 'RT53');
  $rt53->TemplatePath($c->config->{'template_path'});
  $rt53->Instance($instanceInput->{'InstanceName'});
  $rt53->FQDN($hostname->FQDN);
  $rt53->Zone($c->config->{'root_zone'});

  return $rt53;
}

sub _instantiateDnsRecordRT53Tpls {
  my ($self, $c, $instanceInput, $stackTemplate) = @_;
  my ($roleID, $ports);

  $c->model('DB')->Role->DBH($c->model('DB')->dbh);
  $c->model('DB')->Port->DBH($c->model('DB')->dbh);

  $roleID = $c->model('DB')->Role->getID({
    'Role'        => $instanceInput->{'Role'},
    'Environment' => $instanceInput->{'Environment'}
  });

  $ports = $c->model('DB')->Port->list({
    'RoleID' => $roleID
  });

  my @resources;

  for my $port (@{$ports->{'Collection'}}) {
    for my $dnsRecord (@{$port->{'DNSRecords'}}) {

      my $resourceName = $self->_sanitizeResourceName(
        join('',
          $instanceInput->{'InstanceName'},
          'RT53',
          $port->{Provides},
          $dnsRecord->{Type},
          $dnsRecord->{ID}
        )
      );

      my $hostname = new StackIt::EC2::HostName();

      $hostname->InstanceName($instanceInput->{'InstanceName'});
      $hostname->RootZone($c->config->{'root_zone'});
      $hostname->StackName($stackTemplate->StackName);

      my $rt53 = new StackIt::CFN::Template::RT53();

      $rt53->Name($resourceName);
      $rt53->TemplatePath($c->config->{'template_path'});
      $rt53->Instance($instanceInput->{'InstanceName'});
      $rt53->Zone($c->config->{'root_zone'});
      $rt53->Type($dnsRecord->{Type});
      $rt53->TTL($dnsRecord->{TTL}) if defined($dnsRecord->{TTL});

      my $name = $dnsRecord->{Name};
      if ($name !~ /\.$/) {
        # not already fully qualified
        $name .= "." . $hostname->Domain;
      }
      $rt53->FQDN($name);

      if ($dnsRecord->{Type} eq 'NS') {
        # The resource record for an NS record will be the fully qualified
        # hostname of the instance. The zone file line is effectively:
        #   $dnsRecord->{Name} IN NS $instance->FQDN
        $rt53->Resource($hostname->FQDN);
      }
      elsif ($dnsRecord->{Type} eq 'A') {
        # Allow Route53 to assign this using the public IP of the instance.
      }
      else {
        die "Unexpected record type $dnsRecord->{Type}";
      }

      push @resources, $rt53;
    }
  }

  return @resources;
}

sub _sanitizeResourceName {
  my ($self,$name) = @_;
  $name =~ s/[^a-z0-9]//ig;
  return substr($name, 0, 255);
}

no Moose;

1;
