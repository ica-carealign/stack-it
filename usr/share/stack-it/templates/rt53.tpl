    "[% Object.Name %]" : {
      "Type" : "AWS::Route53::RecordSet",
      "Properties" : {
        "HostedZoneName" : "[% Object.Zone %].",
        "Name" : "[% Object.FQDN %]",
        "Type" : "[% Object.Type %]",
        "TTL" : "[% Object.TTL %]",
        "ResourceRecords" : [
[% IF Object.Resource -%]
          "[% Object.Resource %]"
[% ELSE -%]
          { "Fn::GetAtt" : [ "[% Object.Instance %]", "PublicIp" ] }
[% END -%]
        ]
      }
    }
