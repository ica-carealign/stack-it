{
  "AWSTemplateFormatVersion" : "2010-09-09",
  "Description" : "[% Description %]",
  "Parameters" : {
  },
  "Resources" : {
  [%- FOREACH object IN Resources %]
  [%- IF loop.last %]
[% object.processTemplate() %]
  [%- ELSE %]
[% object.processTemplate() FILTER remove('\n$') %],
  [%- END %]
  [%- END %]
  },
  "Outputs" : {
  [%- FOREACH object IN Outputs %]
  [%- IF loop.last %]
[% object.processTemplate() %]
  [%- ELSE %]
[% object.processTemplate() FILTER remove('\n$') %],
  [%- END %]
  [%- END %]
  }
}
