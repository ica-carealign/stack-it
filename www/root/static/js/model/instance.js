function InstanceModel(name) {
  var self = this;

  self.InstanceName    = ko.observable(name);
  self.ImageID         = ko.observable("");
  self.KeyName         = ko.observable("key");
  self.Role            = ko.observable("");
  self.Version         = ko.observable("");
  self.Environment     = ko.observable("");
  self.SubnetID        = ko.observable("");
  self.InstanceType    = ko.observable("t2.small");
  self.SecurityGroupID = ko.observable("");
  self.SkipPuppet      = ko.observable(false);
  self.ScheduleID      = ko.observable("0");
  self.VolumeType      = ko.observable("gp2");
  self.VolumeSize      = ko.observable("default");
}
