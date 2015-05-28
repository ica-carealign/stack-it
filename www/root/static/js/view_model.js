function ViewModel() {
  var self = this;

  self.stackList = ko.observable();
  self.instanceData = ko.observable();
  self.instanceDataTitle = ko.observable();
  self.createInstanceList = ko.observable();
  self.stackData = ko.observable();
  self.stackEvents = ko.observable();
  self.stackInstanceList = ko.observable();
  self.stackInstanceListTitle = ko.observable();
  self.currentStackName = ko.observable();
  self.interval = null;

  self.createInstanceList(null);
  self.stackInstanceList(null);

  self.goToStackData = function() {
    self.stackList(null);
    self.createInstanceList(null);
    self.stackInstanceList(null);
    self.instanceData(null);
    self.stackData(null);

    if(self.interval != null) {
      clearInterval(self.interval);
    }
  }

  self.goToStackCreate = function() {
    self.stackList(null);
    self.createInstanceList(new StackView());
    self.stackInstanceList(null);
    self.instanceData(null);
    self.stackData(null);

    if(self.interval != null) {
      clearInterval(self.interval);
    }

    alignTableHeaders('#stackCreate');
  }

  self.goToStackList = function() {
    self.getStackList();

    if(self.interval != null) {
      clearInterval(self.interval);
    }

    self.interval = setInterval(function() {
      self.getStackList();
    }, 60000);
  }

  self.goToStackInstanceList = function(koObject, jsEvent) {
    if( jsEvent.target.tagName.toLowerCase() === 'a' || (
        jsEvent.target.tagName.toLowerCase() === 'span' &&
        jQuery(jsEvent.target).hasClass('glyphicon-trash') ) ) {
      return;
    } else if( jsEvent.target.tagName.toLowerCase() === 'span' &&
        jQuery(jsEvent.target).hasClass('click-glyph') ) {
        self.goToStackEventsList(koObject, jsEvent);
    } else {
      self.getStackInstanceList(koObject.StackName);
      self.stackInstanceListTitle("Instance List for Stack: " + koObject.StackName);

      if(self.interval != null) {
        clearInterval(self.interval);
      }

      self.interval = setInterval(function() {
        self.getStackInstanceList(koObject.StackName);
      }, 60000);
    }
  }

  self.goToStackEventsList = function(koObject, jsEvent) {
    self.getStackEvents(koObject.StackName);
    
    if(self.interval != null) {
      clearInterval(self.interval);
    }
  }

  self.goToInstanceData = function(koObject, jsEvent) {
    self.instanceData(koObject);
    self.stackInstanceList(null);
    self.stackData(null);
    self.instanceDataTitle("Data for Instance: " + koObject.InstanceName);

    if(self.interval != null) {
      clearInterval(self.interval);
    }

    alignTableHeaders('#instanceData');
  }

  self.OpenRemoteConnection = function(koObject, jsEvent) {
    var instanceInfo = koObject;
    if (instanceInfo.State == "running") {
      if (instanceInfo.Platform == "windows") {
        window.location.href = "rdp://" + instanceInfo.PrivateIP;
      } else {
        window.location.href = "ssh://" + instanceInfo.PrivateIP;
      }
    }
  }
  
  self.stopInstance = function(koObject, jsEvent) {
    var choiceTxt  = 'This action will turn off ' + koObject.InstanceName + '!  ';
        choiceTxt += 'Do you wish to proceed?';
    var choice = confirm(choiceTxt);

    if(choice == true) {
      jQuery.ajax({
        type : 'POST',
        url  : '/stack/stopinstance',
        data : { 'InstanceID' : koObject.InstanceID },
        success : function(json) {
          if(json.json) {
            displayMessage(null, null);
          } else {
            displayMessage(
              koObject.InstanceName + ' has been queued for shut down.',
              'MessageSuccess'
            );
          }
        },
        dataType : 'json'
      });
    }
  }

  self.startInstance = function(koObject, jsEvent) {
    var choiceTxt  = 'This action will turn on ' + koObject.InstanceName + '!  ';
        choiceTxt += 'Do you wish to proceed?';
    var choice = confirm(choiceTxt);

    if(choice == true) {
      jQuery.ajax({
        type : 'POST',
        url  : '/stack/startinstance',
        data : { 'InstanceID' : koObject.InstanceID },
        success : function(json) {
          if(json.json) {
            displayMessage(null, null);
          } else {
            displayMessage(
              koObject.InstanceName + ' has been queued for start up.',
              'MessageSuccess'
            );
          }
        },
        dataType : 'json'
      });
    }
  }

  self.stopStack = function(koObject, jsEvent) {
    var choiceTxt  = 'This action will turn off ' + self.currentStackName() + '!  ';
        choiceTxt += 'Do you wish to proceed?';
    var choice = confirm(choiceTxt);

    if(choice == true) {
      jQuery.ajax({
        type : 'POST',
        url  : '/stack/stop',
        data : { 'StackName' : self.currentStackName() },
        success : function(json) {
          if(json.json) {
            displayMessage(null, null);
          } else {
            displayMessage(
              self.currentStackName() + ' has been queued for shut down.',
              'MessageSuccess'
            );
          }
        },
        dataType : 'json'
      });
    }
  }

  self.startStack = function(koObject, jsEvent) {
    var choiceTxt  = 'This action will turn on ' + self.currentStackName() + '!  ';
        choiceTxt += 'Do you wish to proceed?';
    var choice = confirm(choiceTxt);

    if(choice == true) {
      jQuery.ajax({
        type : 'POST',
        url  : '/stack/start',
        data : { 'StackName' : self.currentStackName() },
        success : function(json) {
          if(json.json) {
            displayMessage(null, null);
          } else {
            displayMessage(
              self.currentStackName() + ' has been queued for start up.',
              'MessageSuccess'
            );
          }
        },
        dataType : 'json'
      });
    }
  }

  self.getStackList = function() {
    jQuery.ajax({
      type : 'GET',
      url : '/stack/list',
      success : function(json) {
        self.createInstanceList(null);
        self.stackInstanceList(null);
        self.stackList(json);
        self.instanceData(null);
        self.stackData(null);
        self.stackEvents(null);
        alignTableHeaders('#stackList');
      },
      dataType : 'json'
    });
  }

  self.getStackEvents = function(stackName) {
    jQuery.ajax({
      type : 'GET',
      url : '/stack/events',
      data : { 'StackName' : stackName },
      success : function(json) {
        self.createInstanceList(null);
        self.stackInstanceList(null);
        self.stackList(null);
        self.instanceData(null);
        self.stackData(null);
        self.stackEvents(json);
        alignTableHeaders('#stackEvents');
      },
      dataType : 'json'
    });
  }

  self.getStackInstanceList = function(stackName) {
    jQuery.ajax({
      type : 'POST',
      url : '/stack/instances',
      data : { 'StackName' : stackName },
      success : function(json) {
        self.createInstanceList(null);
        self.stackList(null);
        self.stackInstanceList(json);
        self.instanceData(null);
        self.stackData(null);
        self.currentStackName(stackName);
      },
      dataType : 'json'
    });
  }

  self.deleteStack = function(koObject, jsEvent) {
    var choiceTxt  = 'All EC2 instances associated with this stack (';
        choiceTxt += koObject.StackName;
        choiceTxt += ') will be deleted!  Do you wish to proceed?';
    var choice = confirm(choiceTxt);

    /*jQuery(jsEvent.target).contents().each(function(index, node) {
      if(node.nodeType === 3) {
        if(node.nodeValue.indexOf("Delete") > -1)
          node.nodeValue = "Queued";
      }
    });*/

    if(choice == true) {
      jQuery.ajax({
        type : 'POST',
        url  : '/stack/delete',
        data : { 'StackName' : koObject.StackName },
        success : function(json) {
          var msg = null;
          var cssClass = null;

          if(!json.json) {
            msg  = 'Your request to delete ' + koObject.StackName + ' has successfully ';
            msg += 'been scheduled and will be removed momentarily.';
            cssClass = 'MessageSuccess';
          }

          displayMessage(msg, cssClass);
        },
        dataType : 'json'
      });
    }
  }

  self.goToPuppetDB = function(koObject, jsEvent) {
    var fqdn = koObject.HostName;
    var pmServer = StackIt.Configuration.PuppetMaster;
    var pmCheck = new RegExp("puppetmaster");

    if(pmCheck.test(fqdn)) {
      fqdn = koObject.PrivateDNS;
      pmServer = koObject.PublicDNS;
    }

    window.open('http://' + pmServer + ':3000/nodes/' + fqdn);
  }
}
