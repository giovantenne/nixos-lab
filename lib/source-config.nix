{ labConfig }:

{
  schemaVersion = labConfig.schemaVersion;

  network = {
    inherit (labConfig.network) masterDhcpIp;
    inherit (labConfig.network) networkBase;
    inherit (labConfig.network) masterHostNumber;
    inherit (labConfig.network) ifaceName;
  };

  hosts = {
    controller = {
      inherit (labConfig.hosts.controller) name;
    };
    clients = {
      inherit (labConfig.hosts.clients) count;
      naming = {
        inherit (labConfig.hosts.clients.naming) prefix;
        inherit (labConfig.hosts.clients.naming) padTo;
      };
    };
  };

  users = {
    admin = {
      inherit (labConfig.users.admin) name;
      inherit (labConfig.users.admin) passwordHash;
      inherit (labConfig.users.admin) sshKeys;
    };
    teacher = {
      inherit (labConfig.users.teacher) name;
      inherit (labConfig.users.teacher) passwordHash;
    };
    student = {
      inherit (labConfig.users.student) name;
      inherit (labConfig.users.student) passwordHash;
      inherit (labConfig.users.student) autologinOnClients;
      inherit (labConfig.users.student) resetHome;
    };
    extraUsers = map (user: {
      inherit (user) name;
      inherit (user) description;
      inherit (user) passwordHash;
      inherit (user) extraGroups;
      inherit (user) sshKeys;
    }) labConfig.users.extraUsers;
  };

  software = labConfig.software;

  features = {
    binaryCache = labConfig.features.binaryCache;
    homeReset = labConfig.features.homeReset;
    screensaver = labConfig.features.screensaver;
    veyon = labConfig.features.veyon;
    guiBackend = labConfig.features.guiBackend;
    appliance = labConfig.features.appliance;
  };

  org = labConfig.org;
  locale = labConfig.locale;
}
