package StackIt::AWS::CFN::Create;

use Moose;
use File::Basename;
use StackIt::Moose::Types;
use S3::AWSAuthConnection;
use S3::QueryStringAuthGenerator;

extends 'StackIt::AWS::CFN';

# String Properties
has 'Action'           => ( is => 'rw', isa => 'CleanStr', default => 'CreateStack' );
has 'BucketName'       => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'StackName'        => ( is => 'rw', isa => 'AlphaNumStr', default => '' );
has 'TemplateURL'      => ( is => 'rw', isa => 'CleanStr', default => '' );
has 'TemplateFilePath' => ( is => 'rw', isa => 'PathStr', default => '' );

# Boolean Properties
has 'DisableRollback' => ( is => 'rw', isa => 'Bool', default => 0 );

# List Properties
has 'Properties' => (
  is      => 'ro',
  isa     => 'ArrayRef',
  default => sub {
    [
      'AWSAccessKeyId',
      'Action',
      'DisableRollback',
      'StackName',
      'TemplateURL',
      'SignatureMethod',
      'SignatureVersion',
      'Timestamp',
      'Version'
    ]
  }
);

# Public Methods
sub uploadTemplateToS3 {
  my ($self) = @_;
  my $data = '';
  my $response = '';

  local $/;

  unless(open(FH, '<' . $self->TemplateFilePath)) {
    $self->Log->error('Cannot open ' . $self->TemplateFilePath . ':  ' . $!);
    return 1;
  } 

  $data = <FH>;

  close(FH);

  my $conn = new S3::AWSAuthConnection(
    $self->AWSAccessKeyId,
    $self->SecretKey
  );

  $conn->set_calling_format('SUBDOMAIN');

  $response = $conn->create_located_bucket($self->BucketName, '');

  if($response->http_response->code != 200) {
    $self->Log->error($response->http_response->message);
    return 1;
  }

  $response = $conn->put(
    $self->BucketName,
    basename($self->TemplateFilePath),
    $data
  );

  if($response->http_response->code != 200) {
    $self->Log->error($response->http_response->message);
    return 1;
  }

  my $generator = new S3::QueryStringAuthGenerator(
    $self->AWSAccessKeyId,
    $self->SecretKey
  );

  $generator->expires_in(600);

  $self->TemplateURL('https://s3.amazonaws.com/' . $self->BucketName . '/' . basename($self->TemplateFilePath));

  return 0;
}

no Moose;

1;
