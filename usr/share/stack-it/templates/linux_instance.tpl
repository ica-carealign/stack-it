    "[% Object.Name %]" : {
      "Type" : "AWS::EC2::Instance",
      "Properties" : {
        "ImageId" : "[% Object.ImageID %]",
        "KeyName" : "[% Object.KeyName %]",
        "Tags" : [
        [%- FOREACH key IN Object.Tags.keys.sort %]
          [%- IF loop.last %]
          { "Key" : "[% key %]", "Value" : "[% Object.Tags.$key %]" }
          [%- ELSE  %]
          { "Key" : "[% key %]", "Value" : "[% Object.Tags.$key %]" },
          [%- END %]
        [%- END %]
        ],
        "UserData" : {
          "Fn::Base64" : {
            "Fn::Join" : [
              "", [
                "#!/bin/bash -ex\n\n",
                "cd /root\n",
                "wget https://[% Object.ArtifactServer %]/pub/scripts/bootstrap\n",
                "chmod 700 bootstrap\n",
                [%- IF Object.SkipPuppet == 1 %]
                  "./bootstrap -s > /var/log/bootstrap.log 2>&1\n",
                [%- ELSE  %]
                  "./bootstrap -e FACTER_ICA_PUPPET_ROLE=[% Object.Role %] -e FACTER_ICA_PUPPET_VERSION=[% Object.Version %] -e FACTER_ICA_PUPPET_ENV=[% Object.Environment %] -e FACTER_ICA_PUPPET_INSTANCE_NAME=[% Object.InstanceName %] -i [% Object.HostName %].[% Object.Domain %] -m [% Object.PuppetMaster %] > /var/log/bootstrap.log 2>&1\n",
                [%- END %]
                [%- IF Object.Role == 'PUPPET_MASTER' %]
                  "wget http://[% Object.ArtifactServer %]/pub/scripts/puppet_master_bootstrap.txt\n",
                  "chmod 700 puppet_master_bootstrap.txt\n",
                  "./puppet_master_bootstrap.txt > /var/log/puppet_master_bootstrap.log 2>&1\n",
                [%- END %]
                "curl -X PUT -H 'Content-Type:' --data-binary ",
                "'{\"Status\" : \"SUCCESS\",",
                "\"Reason\" : \"The server is ready\",",
                "\"UniqueId\" : \"0001\",",
                "\"Data\" : \"Done\"}' ",
                "\"", { "Ref" : "[% Object.WaitHandler %]" },"\"\n"
              ]
            ]
          }
        },
        "Monitoring" : "true",
        "InstanceType" : "[% Object.InstanceType %]",
        "BlockDeviceMappings" : [ {
          "DeviceName" : "[% Object.VolumeDevice %]",
          "Ebs" : {
            [%- IF Object.VolumeSize > 0 %]
            "VolumeSize" : "[% Object.VolumeSize %]",
            [%- END %]
            "VolumeType" : "[% Object.VolumeType %]"
          }
        } ],
        "NetworkInterfaces" : [ {
          "DeviceIndex" : 0,
          "AssociatePublicIpAddress" : "true",
          "PrivateIpAddress" : "[% Object.PrivateIP %]",
          "SubnetId" : "[% Object.SubnetID %]",
          "GroupSet" : [ "[% Object.SecurityGroupID %]", { "Ref" : "[% Object.SecurityGroupRef %]" } ]
        } ]
      },
      "DependsOn" : "[% Object.SecurityGroupRef %]"
    }
