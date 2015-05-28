    "[% Object.Name %]" : {
      "Type" : "AWS::EC2::Instance",
      "Metadata" : {
        "AWS::CloudFormation::Init" : {
          "config" : {
            "files" : {
              "c:\\cfn\\cfn-hup.conf" : {
                "content" : { "Fn::Join" : ["", [
                  "[main]\n",
                  "stack=", { "Ref" : "AWS::StackId" }, "\n",
                  "region=", { "Ref" : "AWS::Region" }, "\n"
                  ]]}
              },
              "c:\\cfn\\hooks.d\\cfn-auto-reloader.conf" : {
                "content": { "Fn::Join" : ["", [
                  "[cfn-auto-reloader-hook]\n",
                  "triggers=post.update\n",
                  "path=Resources.[% Object.Name %].Metadata.AWS::CloudFormation::Init\n",
                  "action=cfn-init.exe -v -s ", { "Ref" : "AWS::StackId" },
                                                 " -r [% Object.Name %]",
                                                 " --region ", { "Ref" : "AWS::Region" }, "\n"
                ]]}
              },
              "c:\\cfn\\software\\puppet-3.4.3.msi" : {
                "source" : "https://[% Object.ArtifactServer %]/pub/software/puppet/puppet-3.4.3.msi"
              }
            },
            "commands" : {
              [%- IF Object.Role %]
              "1-set_role" : {
                "command" : "SETX -m FACTER_ICA_PUPPET_ROLE [% Object.Role %]",
                "waitAfterCompletion" : "0"
              },
              [%- END %]
              [%- IF Object.Environment %]
              "2-set_environment" : {
                "command" : "SETX -m FACTER_ICA_PUPPET_ENV [% Object.Environment %]",
                "waitAfterCompletion" : "0"
              },
              [%- END %]
              [%- IF Object.Version %]
              "3-set_version" : {
                "command" : "SETX -m FACTER_ICA_PUPPET_VERSION [% Object.Version %]",
                "waitAfterCompletion" : "0"
              },
              [%- END %]
              [%- IF Object.InstanceName %]
              "4-set_instance_name" : {
                "command" : "SETX -m FACTER_ICA_PUPPET_INSTANCE_NAME [% Object.InstanceName %]",
                "waitAfterCompletion" : "0"
              },
              [%- END %]
              [%- IF Object.HostName %]
              "5-set_hostname" : {
                "command" : "Powershell.exe \"$computer = Get-WMIObject Win32_ComputerSystem; $computer.Rename('[% Object.HostName %]'); shutdown -t 0 -r -f\"",
                "waitAfterCompletion" : "forever"
              },
              [%- END %]
              [%- IF Object.Domain %]
              "6-set_domain" : {
                "command" : "Powershell.exe \"$nics = Get-WMIObject Win32_NetworkAdapterConfiguration -Filter IPEnabled=TRUE; Foreach($nic in $nics) { $nic.SetDNSDomain('[% Object.Domain %]') }\"",
                "waitAfterCompletion" : "0"
              },
              [%- END %]
              "7-install" : {
                "command" : "C:\\Windows\\System32\\msiexec /qn /L C:\\cfn\\msiexec.log /i C:\\cfn\\software\\puppet-3.4.3.msi PUPPET_MASTER_SERVER=[% Object.PuppetMaster %]",
                "waitAfterCompletion" : "0"
              }
            },
            "services" : {
              "windows" : {
               "cfn-hup" : {
                 "enabled" : "true",
                 "ensureRunning" : "true",
                 "files" : ["c:\\cfn\\cfn-hup.conf", "c:\\cfn\\hooks.d\\cfn-auto-reloader.conf"]
                }
              }
            }
          }
        }
      },
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
                "<script>\n",
                "cfn-init.exe -v -s ", { "Ref" : "AWS::StackId" },
                " -r [% Object.Name %]", " --region ", { "Ref" : "AWS::Region" }, "\n",
                "cfn-signal.exe -e %ERRORLEVEL% ",
                { "Fn::Base64" : { "Ref" : "[% Object.WaitHandler %]" }}, "\n",
                "</script>"
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
          "GroupSet" : [ "[% Object.SecurityGroupID %]", { "Ref": "[% Object.SecurityGroupRef %]" } ]
        } ]
      },
      "DependsOn" : "[% Object.SecurityGroupRef %]"
    }
