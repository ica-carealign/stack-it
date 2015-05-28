package StackIt::Moose::Types;

use Moose;
use Moose::Util::TypeConstraints;

use StackIt::Verify;

subtype 'CleanStr'
  => as 'Str'
  => where { STRING_REGEX || /^$/};

subtype 'DBI'
  => as 'Object'
  => where { ref ($_) =~ m/^DBI::db$/ };

subtype 'PathStr'
  => as 'Str'
  => where { PATH_REGEX };

subtype 'AlphaNumStr'
  => as 'Str'
  => where { ALPHNUM_REGEX };

subtype 'BooleanStr'
  => as 'Str'
  => where { BOOLEAN_STR_REGEX };

subtype 'NetMaskStr'
  => as 'Str'
  => where { NET_MASK_REGEX };

subtype 'Log'
  => as 'Object'
  => where { ref($_) =~ m/^StackIt::Log$/ };

subtype 'DnsResourceRecordType'
  => as 'Object'
  => where { RRTYPE_REGEX };

no Moose;

1;
