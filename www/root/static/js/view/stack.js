function StackView() {
  var self = this;

  self.idxCounter = 0;
  self.nameGenerator = new NameGenerator();

  self.stackDescription = ko.observable(StackIt.Configuration.DefaultStackDescription);
  self.stackName = ko.observable(self.nameGenerator.Generate());
  self.integrationChecked = ko.observable(false);
  self.currentInstance = ko.observable(new InstanceView());
  self.stackEnvironment = ko.observable();

  self.roleCollection = new RoleCollection();

  self.instances = ko.observableArray();
  self.stackEnvironments = ko.observableArray();
  self.schedules = ko.observableArray();
  self.scheduleID = ko.observable();

  self.addInstance = function() {
    var instanceView = new InstanceView(self.idxCounter++, self.stackName());

    instanceView.RoleCollection(self.roleCollection);
    instanceView.Instance.ScheduleID(self.scheduleID());

    self.schedules().forEach(function(schedule) {
      instanceView.Schedules.push({
        description: schedule.description,
        value: schedule.value
      });
    });

    self.DisableStackNameInput();
    self.instances.push(instanceView);
    alignTableHeaders('#stackCreate');
  }

  self.removeInstance = function(koObject, jsEvent) {
    self.instances.remove(koObject);
  }

  self.cancel = function() {
    self.reset();
    self.EnableStackNameInput();
    self.stackName(self.nameGenerator.Generate());

    jQuery('#stackName').css('color', 'black');
    jQuery('#optionStackName').css('color', 'black');
    jQuery('#stackCreateSubmit').removeAttr('disabled');
    jQuery('#instanceAddButton').removeAttr('disabled');
    hideMessage();
  }

  self.reset = function() {
    self.instances.removeAll();
    self.integrationChecked(false);
    self.idxCounter = 0;
  }

  self.cancelByBtn = function() {
    self.cancel();
    self.stackEnvironment('');
    jQuery('#StackSchedule').val(StackIt.Configuration.DefaultScheduleID).change();
  }

  self.submit = function() {
    var postArray = [];

    self.instances().forEach(function(instance) {
      postArray.push(ko.toJSON(instance.Instance));
    });

    jQuery.post(
      "/stack/create", 
      { 
        'StackName': self.stackName(),
        'StackDescription': self.stackDescription(),
        'Instances': JSON.stringify(postArray)
      },
      function(json) {
        var msg = null;
        var cssClass = null;

        if(!json.json) {
          msg = self.stackName() + ' has successfully been scheduled for creation.';
          cssClass = 'MessageSuccess';
        }

        displayMessage(msg, cssClass);
        setTimeout(function() { window.location = '/'; }, 6000);
      }
    );
  }

  self.addStackInstance = function(imageID, role, version, environment) {
    var instanceView = new InstanceView(self.idxCounter++, self.stackName());

    instanceView.RoleCollection(self.roleCollection);
    instanceView.Instance.ScheduleID(self.scheduleID());

    self.schedules().forEach(function(schedule) {
      instanceView.Schedules.push({
        description: schedule.description,
        value: schedule.value
      });
    });

    instanceView.Instance.ImageID(imageID);
    instanceView.Instance.Role(role);
    instanceView.Instance.Version(version);
    instanceView.Instance.Environment(environment);

    instanceView.OSOnChange({}, { cancelable: false});
    instanceView.RoleOnChange({}, { cancelable: false});
    instanceView.VersionOnChange({}, { cancelable: false});

    self.instances.push(instanceView);
  }

  self.openStackOptions = function(koObject, jsEvent) {
    jQuery('#stackOptionsWrapper').toggle();
    jQuery('#stackCreateWrapper').toggle();
    jQuery('#stackCreateTitle').toggle();
  }

  self.closeStackOptions = function(koObject, jsEvent) {
    jQuery('#stackOptionsWrapper').toggle();
    jQuery('#stackCreateWrapper').toggle();
    jQuery('#stackCreateTitle').toggle();
  }

  self.openInstanceOptions = function(koObject, jsEvent) {
    self.currentInstance(koObject);
    jQuery('#instanceOptionsWrapper').toggle();
    jQuery('#stackCreateWrapper').toggle();
    jQuery('#stackCreateTitle').toggle();
  }

  self.closeInstanceOptions = function(koObject, jsEvent) {
    jQuery('#instanceOptionsWrapper').toggle();
    jQuery('#stackCreateWrapper').toggle();
    jQuery('#stackCreateTitle').toggle();
  }

  self.StackEnvOnChange = function(koObject, jsEvent) {
    // This cannot be set to === true because jsEvent.cancelable
    // does not exist in some events
    if (jsEvent.cancelable !== false) return;

    self.reset();
    self.DisableStackNameInput();

    if(self.stackEnvironment()) {
      jQuery.getJSON('/role/list/' + self.stackEnvironment(), {}, parseReturnData);
    }

    function parseReturnData(data) {
      var env = jQuery('#stackEnvironment').children(':selected').text();
      var roles = {};

      // Display any collection errors...
      if(data.json.Log.Errors.length > 0) {
        displayMessage(null, null);
      }

      jQuery.each(data.json.Collection, function(key, val) {
        // Display errors for individual objects...
        if(val.Log.Errors.length > 0) {
          displayMessage(null, null);
        }

        // Consolidate the role records...
        if(val.Role in roles) {
          if(val.Version in roles[val.Role].versions) {
          } else {
            roles[val.Role].versions.push(
              {
                version:   val.Version,
                instances: val.NumberOfInstances
              }
            );
          }
        } else {
          roles[val.Role] = {
            os: val.OS,
            versions: [
              {
                version:   val.Version,
                instances: val.NumberOfInstances
              }
            ]
          }
        }
      });

      for(role in roles) {
        var version   = 0;
        var instances = 0;

        jQuery.each(roles[role].versions, function(key, val) {
          if(version == 0) {
            version = val.version;
            instances = val.instances;
          } else {
            if(val.version < val.version) {
              version = val.version;
              instances = val.instances;
            }
          }
        });

        for(var idx = 0; idx < instances; idx++) {
          self.addStackInstance(roles[role].os, role, version, env.toUpperCase());
        }
      }
    }
  }

  self.StackScheduleOnChange = function(koObject, jsEvent) {
    jQuery.each(self.instances(), function(idx, instance) {
      instance.Instance.ScheduleID(self.scheduleID());
    });
  }

  self.DisableStackNameInput = function() {
    jQuery('#stackName').attr('disabled', 'disabled');
    jQuery('#optionStackName').attr('disabled', 'disabled');
  }

  self.EnableStackNameInput = function() {
    jQuery('#stackName').removeAttr('disabled');
    jQuery('#optionStackName').removeAttr('disabled');
  }

  self.StackNameOnChange = function(koObject, jsEvent) {
    var text = jQuery('#' + jsEvent.target.id).val();
    var message  = 'Stack Name should only contain alpha-numeric ';
        message += ' characters and be at least 6 characters long.';

    if(/^[A-Za-z0-9]{6,}$/.test(text)) {
      jQuery('#stackName').css('color', 'black');
      jQuery('#optionStackName').css('color', 'black');
      jQuery('#stackCreateSubmit').removeAttr('disabled');
      jQuery('#instanceAddButton').removeAttr('disabled');
      hideMessage();
    } else {
      jQuery('#stackName').css('color', 'red');
      jQuery('#optionStackName').css('color', 'red');
      jQuery('#stackCreateSubmit').attr('disabled', 'disabled');
      jQuery('#instanceAddButton').attr('disabled', 'disabled');
      displayMessage(message, null, 1);
    }
  }

  self.getEnvironments = function() {
    self.stackEnvironments.push({environmentName: "...", value: "" });

    jQuery.getJSON('/environment/list', {}, parseReturnData);

    function parseReturnData(data) {
      // Display any collection errors...
      if(data.json.Log.Errors.length > 0) {
        displayMessage(null, null);
      }

      jQuery.each(data.json.Collection, function(key, val) {
        // Display errors for individual objects...
        if(val.Log.Errors.length > 0) {
          displayMessage(null, null);
          return false;
        }

        self.stackEnvironments.push({
          environmentName: val.Environment,
          value: val.Environment
        });
      });
    }
  }

  self.getRoles = function() {
    jQuery.getJSON('/role/list', {}, parseReturnData);

    function parseReturnData(data) {
      // Display any collection errors...
      if(data.json.Log.Errors.length > 0) {
        displayMessage(null, null);
      }

      jQuery.each(data.json.Collection, function(key, val) {
        // Display errors for individual objects...
        if(val.Log.Errors.length > 0) {
          displayMessage(null, null);
          return false;
        }

        // Have to take into account the first Role record whose
        // OS and Role values are empty...
        if(val.OS != '' && val.Role != '') {
          self.roleCollection.add(val);
        }
      });
    }
  }

  self.getSchedules = function() {
    self.schedules.push({description: "...", value: "0" });

    jQuery.getJSON('/schedule/list', {}, parseReturnData);

    function parseReturnData(data) {
      // Display any collection errors...
      if(data.json.Log.Errors.length > 0) {
        displayMessage(null, null);
      }

      jQuery.each(data.json.Collection, function(key, val) {
        // Display errors for individual objects...
        if(val.Log.Errors.length > 0) {
          displayMessage(null, null);
          return false;
        }

        self.schedules.push({
          description: val.Description,
          value: val.ID
        });
      });

      if(StackIt.Configuration.DefaultScheduleID < self.schedules().length) {
        jQuery('#StackSchedule').val(StackIt.Configuration.DefaultScheduleID).change();
      }
    }
  }

  self.getEnvironments();
  self.getRoles();
  self.getSchedules();
}
