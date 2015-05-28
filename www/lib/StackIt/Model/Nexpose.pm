package StackIt::Model::Nexpose;

use Moose;
use StackIt::Nexpose::Session;

extends 'StackIt::Model::Utils';

# Public Methods
sub scan {
  my ($self, $c) = @_;

  my $stack_name   = $c->request->parameters->{'StackName'};
  my $subnet       = $c->config->{'instance_subnet'};

  my $nexpose_site = $c->request->parameters->{'SiteName'};
  my $nexpose_user = $c->config->{'nexpose_user'};
  my $nexpose_pass = $c->config->{'nexpose_password'};
  my $nexpose_url  = $c->config->{'nexpose_api_uri'};
  
  my $db_instances = new StackIt::DB::Collection::Instance(
    'DBH'           => $c->model('DB')->dbh,
    'StackName'     => $stack_name
  );

  my $nexposeObj = new StackIt::Nexpose::Session;

  $nexposeObj->URL($nexpose_url);
  $nexposeObj->User($nexpose_user);
  $nexposeObj->Password($nexpose_pass);
  $nexposeObj->SiteName($nexpose_site);

  foreach my $instance (@{$db_instances->Collection}) {
    # TODO:  Get rid of this hard coded exclusion...
    next if($instance->Instance eq $stack_name . 'TC');

    # TODO:  Fix this hack...
    my $ip = $subnet;
    my $lastOctet = $instance->PrivateIPID;
    $ip =~ s/0\/24/$lastOctet/;
    $nexposeObj->addAsset($ip);
  }

  $nexposeObj->login();
  $nexposeObj->getSiteIDByName();
  $nexposeObj->getSiteAssetIDs();
  $nexposeObj->deleteAssets();
  $nexposeObj->getSiteConfig();
  $nexposeObj->updateSiteConfig();
  $nexposeObj->scan();
  $nexposeObj->logout();

  $self->_logMessages($nexposeObj);
  return 1 if(@{$nexposeObj->Log->Errors});

  return 0;
}

no Moose;

1;
