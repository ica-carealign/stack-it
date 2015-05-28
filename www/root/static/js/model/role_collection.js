function RoleCollection() {
  var self = this;

  self.Roles = {};
  self.OSs = {};

  self.add = function(json) {
    // Create or update a Roles element...
    if(json.Role in self.Roles) {
      if(json.Version in self.Roles[json.Role].versions) {
        self.addEnvironment(json.Role, json.Version, json.Environment);
      } else {
        self.addVersion(json.Role, json.Version, json.Environment);
      }
    } else {
      self.Roles[json.Role] = {
        description: json.Description,
        versions: {}
      }

      self.addVersion(json.Role, json.Version, json.Environment);

      // Create or update an OSs element...
      self.addOS(json.OS, json.Description, json.Role); 
    }
  }

  self.addOS = function(os, description, role) {
    if(os in self.OSs) {
      self.OSs[os].push({
        description: description,
        role: role
      });
    } else {
      self.OSs[os] = [{
        description: description,
        role: role
      }];
    } 
  }

  self.addVersion = function(role, version, environment) {
    self.Roles[role].versions[version] = [ environment ];
  }

  self.addEnvironment = function(role, version, environment) {
    self.Roles[role].versions[version].push(environment);
  }

  self.roleOptions = function(image) {
    var options = [{
      roleName: "...",
      value: ""
    }];

    for (os in self.OSs) {
      if(os == image) {
        for (idx in self.OSs[os]) {
          options.push({
            roleName: self.OSs[os][idx].description,
            value: self.OSs[os][idx].role
          });
        }
      }
    }

    return options;
  }

  self.versionOptions = function(role) {
    var options = [{
      versionName: "...",
      value: ""
    }];

    for (version in self.Roles[role].versions) {
      var formattedVersion = version.replace(/^v/, '');
      formattedVersion = formattedVersion.replace(/_/g, '.');

      options.push({
        versionName: formattedVersion,
        value: version
      });
    }

    return options;
  }

  self.environmentOptions = function(role, version) {
    var options = [{
      environmentName: "...",
      value: ""
    }];

    for (idx in self.Roles[role].versions[version]) {
      options.push({
        environmentName: self.Roles[role].versions[version][idx],
        value: self.Roles[role].versions[version][idx].toUpperCase()
      });
    }

    return options;
  }
}
