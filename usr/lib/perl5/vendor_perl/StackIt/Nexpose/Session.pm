package StackIt::Nexpose::Session;

use Moose;
use StackIt::Moose::Types;

extends 'StackIt::Nexpose';

# String Properties
has 'User'       => ( is => 'rw', isa => 'CleanStr', default => "" );
has 'Password'   => ( is => 'rw', isa => 'CleanStr', default => "" );
has 'SessionID'  => ( is => 'rw', isa => 'CleanStr', default => "" );
has 'SiteName'   => ( is => 'rw', isa => 'CleanStr', default => "" );
has 'SiteConfig' => ( is => 'rw', isa => 'Str', default => "" );

# Integer Properties
has 'SiteID' => ( is => 'rw', isa => 'Int', default => 0 );

# List Properties
has 'Assets'   => ( is => 'ro', isa => 'ArrayRef', default => sub { [] } );
has 'AssetIDs' => ( is => 'ro', isa => 'ArrayRef', default => sub { [] } );

# Public Methods
sub addAsset {
  my  ($self, $asset) = @_;
  push @{$self->{'Assets'}}, $asset;
}

sub login {
  my ($self) = @_;

  foreach my $property ("User", "Password") {
    unless($self->$property) {
      $self->Log->error($property . ' is required');
      return;
    }
  }

  my $body  = '<LoginRequest user-id="' . $self->User . '" ';
     $body .= 'password="' . $self->Password . '"></LoginRequest>';

  my $content = $self->_post($body);

  $self->SessionID($content->{'session-id'}) if($content);
}

sub logout {
  my ($self) = @_;

  return unless($self->SessionID);

  my $body  = '<LogoutRequest session-id="';
     $body .= $self->SessionID . '"></LogoutRequest>';

  my $content = $self->_post($body);

  $self->SessionID("") if($content);
}

sub getSiteIDByName {
  my ($self) = @_;

  foreach my $property ("SessionID", "SiteName") {
    unless($self->$property) {
      $self->Log->error($property . ' is required');
      return;
    }
  }

  my $body = '<SiteListingRequest session-id="';
     $body .= $self->SessionID . '"></SiteListingRequest>';

  my $sites =  $self->_post($body);

  if($sites) {
    if(exists $sites->{'SiteSummary'}->{$self->SiteName}) {
      $self->SiteID($sites->{'SiteSummary'}->{$self->SiteName}->{'id'});
    } elsif($sites->{'SiteSummary'}->{'name'} eq $self->SiteName) {
      $self->SiteID($sites->{'SiteSummary'}->{'id'});
    }
  }
}

sub getSiteConfig {
  my ($self) = @_;

  foreach my $property ("SessionID", "SiteID") {
    unless($self->$property) {
      $self->Log->error($property . ' is required');
      return;
    }
  }

  my $body  = '<SiteConfigRequest session-id="' . $self->SessionID;
     $body .= '" site-id="' . $self->SiteID . '"></SiteConfigRequest>';

  my $content = $self->_post($body, 1);

  $self->SiteConfig($content) if($content);
}

sub getSiteAssetIDs {
  my ($self) = @_;

  foreach my $property ("SessionID", "SiteID") {
    unless($self->$property) {
      $self->Log->error($property . ' is required');
      return;
    }
  }

  my $body  = '<SiteDeviceListingRequest session-id="' . $self->SessionID;
     $body .= '" site-id="' . $self->SiteID . '"></SiteDeviceListingRequest>';

  my $content = $self->_post($body);

  if($content) {
    foreach my $deviceID (keys %{$content->{'SiteDevices'}->{'device'}}) {
      push @{$self->{'AssetIDs'}}, $deviceID;
    }
  }
}

sub deleteAssets {
  my ($self) = @_;

  unless($self->SessionID) {
    $self->Log->error('SessionID is required');
    return;
  }

  foreach my $assetID (@{$self->AssetIDs}) {
    my $body  = '<DeviceDeleteRequest session-id="' . $self->SessionID;
       $body .= '" device-id="' . $assetID . '"></DeviceDeleteRequest>';

    $self->_post($body);
  }
}

sub updateSiteConfig {
  my ($self) = @_;
  my $hosts = "";

  foreach my $property ("SessionID", "SiteConfig") {
    unless($self->$property) {
      $self->Log->error($property . ' is required');
      return;
    }
  }

  foreach my $asset (@{$self->Assets}) {
    $hosts .= '<range from="' . $asset . '"/>';
  }

  return unless($hosts);

  my $config = $self->SiteConfig;

  $config =~ s/<\/?SiteConfigResponse[^>]*>//g;
  $config =~ s/<Hosts>\n(.*\n)+<\/Hosts>/<Hosts>$hosts<\/Hosts>/;

  my $body  = '<SiteSaveRequest session-id="' . $self->SessionID;
     $body .= '">' . $config . '</SiteSaveRequest>';

  $self->_post($body);
}

sub scan {
  my ($self) = @_;

  foreach my $property ("SessionID", "SiteID") {
    unless($self->$property) {
      $self->Log->error($property . ' is required');
      return;
    }
  }

  my $body  = '<SiteScanRequest session-id="' . $self->SessionID;
     $body .= '" site-id="' . $self->SiteID . '"></SiteScanRequest>';

  $self->_post($body);
}

no Moose;

1;
