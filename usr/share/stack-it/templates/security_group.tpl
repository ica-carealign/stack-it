    "[% Object.Name %]" : {
      "Type" : "AWS::EC2::SecurityGroup",
      "Properties" : {
        "GroupDescription" : "[% Object.Description %]",
        "VpcId" : "[% Object.VpcID %]",
        "SecurityGroupIngress" : [
        [%- FOREACH port IN Object.Ports %]
          [%- IF port.TCP == 1 && port.UDP == 0 %]
          {
            "IpProtocol" : "tcp",
            "FromPort" : "[% port.Port %]",
            "ToPort" : "[% port.Port %]",
            [%- IF port.External == 1 %]
            "CidrIp" : "0.0.0.0/0"
            [%- ELSE %]
            "CidrIp" : "[% Object.Subnet %]"
            [%- END %]
          [%- ELSIF port.TCP == 0 && port.UDP == 1 %]
          {
            "IpProtocol" : "udp",
            "FromPort" : "[% port.Port %]",
            "ToPort" : "[% port.Port %]",
            [%- IF port.External == 1 %]
            "CidrIp" : "0.0.0.0/0"
            [%- ELSE %]
            "CidrIp" : "[% Object.Subnet %]"
            [%- END %]
          [%- ELSIF port.TCP == 1 && port.UDP == 1 %]
          {
            "IpProtocol" : "tcp",
            "FromPort" : "[% port.Port %]",
            "ToPort" : "[% port.Port %]",
            [%- IF port.External == 1 %]
            "CidrIp" : "0.0.0.0/0"
            [%- ELSE %]
            "CidrIp" : "[% Object.Subnet %]"
            [%- END %]
          },
          {
            "IpProtocol" : "udp",
            "FromPort" : "[% port.Port %]",
            "ToPort" : "[% port.Port %]",
            [%- IF port.External == 1 %]
            "CidrIp" : "0.0.0.0/0"
            [%- ELSE %]
            "CidrIp" : "[% Object.Subnet %]"
            [%- END %]
          [%- END %]
          [%- IF loop.last %]
          }
          [%- ELSE %]
          },
          [%- END %]
        [%- END %]
        ]
      }
    }
