function InstanceView(idx, stackName) {
  var self = this;

  self._Roles = {};

  self.Index = idx || 0;
  self.Instance = new InstanceModel(stackName + "Instance" + self.Index);
  self.StackName = stackName;

  self.enableRoles        = ko.observable(false);
  self.enableVersions     = ko.observable(false);
  self.enableEnvironments = ko.observable(false);
  self.Schedules          = ko.observableArray();

  self.RoleCollection = function(value) {
    if(value) {
      self._Roles = value;
    } else {
      return self._Roles;
    }
  }

  self.OSs = [
    { OSName: "...",                           value: ""                        },
    { OSName: "CentOS 5 - Base",               value: "centos_5_base_image"     },
    { OSName: "CentOS 6 - Base",               value: "centos_6_base_image"     },
    { OSName: "Windows Server 2008 R2 - Base", value: "windows_2008_base_image" },
    { OSName: "Windows Server 2008 R2 - HISP", value: "windows_2008_hisp_image" },
    { OSName: "Windows Server 2008 R2 - AUI",  value: "windows_2008_aui_image" },
    { OSName: "Windows Server 2012 R2 - Base", value: "windows_2012_base_image" },
    { OSName: "Windows Server 2008 R2 - Test", value: "windows_2008_test_image" },
  ];

  self.Roles        = ko.observableArray();
  self.Versions     = ko.observableArray();
  self.Environments = ko.observableArray();

  self.InstanceTypes = [
    { description: "1 vCPU, 1GiB RAM (t2.micro)",     value: "t2.micro"   },
    { description: "1 vCPU, 2GiB RAM (t2.small)",     value: "t2.small"   },
    { description: "2 vCPU, 4GiB RAM (t2.medium)",    value: "t2.medium"  },
    { description: "1 vCPU, 3.75GiB RAM (m3.medium)", value: "m3.medium"  },
    { description: "2 vCPU, 7.5GiB RAM (m3.large)",   value: "m3.large"   },
    { description: "4 vCPU, 15GiB RAM (m3.xlarge)",   value: "m3.xlarge"  },
    { description: "8 vCPU, 30GiB RAM (m3.2xlarge)",  value: "m3.2xlarge" },
    { description: "2 vCPU, 3.75GiB RAM (c3.large)",  value: "c3.large"   },
    { description: "4 vCPU, 7.5GiB RAM (c3.xlarge)",  value: "c3.xlarge"  },
    { description: "8 vCPU, 15GiB RAM (c3.2xlarge)",  value: "c3.2xlarge" },
    { description: "16 vCPU, 30GiB RAM (c3.4xlarge)", value: "c3.4xlarge" },
    { description: "32 vCPU, 60GiB RAM (c3.8xlarge)", value: "c3.8xlarge" }
  ];

  self.VolumeTypes = [
    { description: "Magnetic", value: "standard" },
    { description: "SSD",      value: "gp2"      }
  ]

  self.OSOnChange = function(koObject, jsEvent) {
    if (jsEvent.cancelable === true) return;

    self.setOptionDefaults([ 'Roles', 'Versions', 'Environments' ]);

    if(self.Instance.ImageID()) {
      self.Roles(self.RoleCollection().roleOptions(self.Instance.ImageID()));
      self.enableRoles(true);

      self.Instance.InstanceName(stackName + "Instance" + self.Index);
    }
  }

  self.RoleOnChange = function(koObject, jsEvent) {
    if (jsEvent.cancelable === true) return;

    self.setOptionDefaults([ 'Versions', 'Environments' ]);

    if (self.Instance.Role()) {
      self.Versions(self.RoleCollection().versionOptions(self.Instance.Role()));
      self.enableVersions(true);

      self.Instance.InstanceName(
        self.Instance.InstanceName().replace(
          'Instance',
          self.Instance.Role().replace(/_/g, '')
        )
      );

      // Automatically choose the version if there is only one choice...
      if(self.Versions().length == 2) {
        self.Instance.Version(self.Versions()[1].value);
        self.VersionOnChange({}, { cancelable: false });
      }
    }
  }

  self.VersionOnChange = function(koObject, jsEvent) {
    if (jsEvent.cancelable === true) return;

    self.setOptionDefaults([ 'Environments' ]);

    if (self.Instance.Role() && self.Instance.Version()) {
      self.Environments(self.RoleCollection().environmentOptions(
        self.Instance.Role(),
        self.Instance.Version()
      ));

      self.enableEnvironments(true);

      // Automatically choose the environment if there is only one choice...
      if(self.Environments().length == 2) {
        self.Instance.Environment(self.Environments()[1].value);
      }
    }
  }

  self.InstanceNameOnChange = function () {
    var text = jQuery('#instanceName').val();
    var message  = 'Instance Name should only contain alpha-numeric ';
        message += ' characters and be at least 6 characters long.';

    if(/^[A-Za-z0-9]{6,}$/.test(text)) {
      jQuery('#instanceName').css('color', 'black');
      jQuery('#stackCreateSubmit').removeAttr('disabled');
      jQuery('#instanceAddButton').removeAttr('disabled');
      jQuery('#instanceBackButton').removeAttr('disabled');
      hideMessage();
    } else {
      jQuery('#instanceName').css('color', 'red');
      jQuery('#stackCreateSubmit').attr('disabled', 'disabled');
      jQuery('#instanceAddButton').attr('disabled', 'disabled');
      jQuery('#instanceBackButton').attr('disabled', 'disabled');
      displayMessage(message, null, 1);
    }
  }

  self.setOptionDefaults = function(arrayProperties) {
    for (idx in arrayProperties) {
      self[arrayProperties[idx]].removeAll();
      self['enable' + arrayProperties[idx]](false);

      switch(arrayProperties[idx]) {
        case 'Roles':
          self.Roles.push({ roleName: "...", value: "" });
          break;
        case 'Versions':
          self.Versions.push({ versionName: "...", value: "" });
          break;
        case 'Environments':
          self.Environments.push({ environmentName: "...", value: "" });
          break;
        default:
      }
    }
  }

  self.setOptionDefaults([ 'Roles', 'Versions', 'Environments' ]);
}
