{ lib, rawConfig, cachePublicKey ? null, adminSshKey ? null, cachePort ? 5000, pxeHttpPort ? 8080 }:

let
  configRoot =
    if rawConfig ? lab then
      rawConfig.lab
    else
      rawConfig;

  networkConfig =
    if configRoot ? network then
      configRoot.network
    else
      {
        inherit (configRoot) masterDhcpIp;
        inherit (configRoot) networkBase;
        inherit (configRoot) masterHostNumber;
        inherit (configRoot) ifaceName;
      };

  hostsConfig = configRoot.hosts or {};
  clientsConfig = hostsConfig.clients or {};
  clientCount =
    if clientsConfig ? count then
      clientsConfig.count
    else
      configRoot.pcCount;
  clientNaming = clientsConfig.naming or {};
  clientPrefix = clientNaming.prefix or "pc";
  clientPadTo = clientNaming.padTo or 2;
  controllerConfig = hostsConfig.controller or {};

  usersConfig = configRoot.users or {};
  adminConfig = usersConfig.admin or {};
  teacherConfig = usersConfig.teacher or {};
  studentConfig = usersConfig.student or {};
  extraUsersConfig =
    if usersConfig ? extraUsers then
      usersConfig.extraUsers
    else
      configRoot.extraUsers or [];

  featuresConfig = configRoot.features or {};
  binaryCacheFeatureConfig = featuresConfig.binaryCache or {};
  homeResetFeatureConfig = featuresConfig.homeReset or {};
  screensaverFeatureConfig = featuresConfig.screensaver or {};
  veyonFeatureConfig = featuresConfig.veyon or {};
  guiBackendFeatureConfig = featuresConfig.guiBackend or {};
  applianceFeatureConfig = featuresConfig.appliance or {};

  orgConfig =
    if configRoot ? org then
      configRoot.org
    else
      {
        inherit (configRoot) homepageUrl;
        git = {
          student = {
            name = configRoot.studentGitName;
            email = configRoot.studentGitEmail;
          };
          admin = {
            name = configRoot.adminGitName;
            email = configRoot.adminGitEmail;
          };
        };
      };

  localeConfig =
    if configRoot ? locale then
      configRoot.locale
    else
      {
        inherit (configRoot) timeZone;
        inherit (configRoot) defaultLocale;
        inherit (configRoot) extraLocale;
        inherit (configRoot) keyboardLayout;
        inherit (configRoot) consoleKeyMap;
      };

  softwareConfig = configRoot.software or {};
  softwareHostConfig = softwareConfig.hostScopes or {};
  softwareDesktopConfig = softwareConfig.desktop or {};
  softwareVscodeConfig = softwareConfig.vscode or {};
  softwarePresets =
    if softwareConfig ? presets then
      softwareConfig.presets
    else
      [
        "base-cli"
        "desktop"
        "dev-tools"
        "container"
        "network-admin"
        "publishing"
        "python"
        "lua"
        "java"
        "node"
        "php"
        "browser"
        "editor"
      ];
  softwareControllerPresets = softwareHostConfig.controller or [];
  softwareClientPresets = softwareHostConfig.clients or [];
  softwareExtraPackages = softwareConfig.extraPackages or [];
  defaultFavoriteApps = [
    "com.mitchellh.ghostty.desktop"
    "chromium-browser.desktop"
    "code.desktop"
    "org.gnome.Nautilus.desktop"
    "org.gnome.TextEditor.desktop"
  ];
  softwareStudentFavorites = softwareDesktopConfig.studentFavorites or defaultFavoriteApps;
  softwareStaffFavorites = softwareDesktopConfig.staffFavorites or defaultFavoriteApps;
  softwareStudentVscodePresets = softwareVscodeConfig.studentPresets or [ "web" "java" ];
  softwareAdminVscodePresets = softwareVscodeConfig.adminPresets or [];

  adminName =
    if adminConfig ? name then
      adminConfig.name
    else if configRoot ? adminUser then
      configRoot.adminUser
    else
      "admin";
  teacherName =
    if teacherConfig ? name then
      teacherConfig.name
    else
      configRoot.teacherUser;
  studentName =
    if studentConfig ? name then
      studentConfig.name
    else
      configRoot.studentUser;

  adminPasswordHash =
    if adminConfig ? passwordHash then
      adminConfig.passwordHash
    else
      configRoot.adminPassword;
  teacherPasswordHash =
    if teacherConfig ? passwordHash then
      teacherConfig.passwordHash
    else
      configRoot.teacherPassword;
  studentPasswordHash =
    if studentConfig ? passwordHash then
      studentConfig.passwordHash
    else
      configRoot.studentPassword;

  adminSshKeys =
    if adminConfig ? sshKeys then
      adminConfig.sshKeys
    else if configRoot ? adminSshKeys then
      configRoot.adminSshKeys
    else if adminSshKey == null then
      []
    else
      [ adminSshKey ];
  adminPrimarySshKey =
    if adminSshKeys == [] then
      null
    else
      builtins.head adminSshKeys;

  studentAutologinOnClients =
    if studentConfig ? autologinOnClients then
      studentConfig.autologinOnClients
    else
      true;
  studentResetHome =
    if studentConfig ? resetHome then
      studentConfig.resetHome
    else
      true;

  masterHostNumber = networkConfig.masterHostNumber;
  networkBase = networkConfig.networkBase;
  masterIp = "${networkBase}.${toString masterHostNumber}";

  controllerName =
    if controllerConfig ? name then
      controllerConfig.name
    else
      "${clientPrefix}${toString masterHostNumber}";

  padNumber = padTo: number:
    let
      numberString = toString number;
      zeroCount = padTo - builtins.stringLength numberString;
      zeros =
        if zeroCount <= 0 then
          ""
        else
          builtins.concatStringsSep "" (builtins.genList (_: "0") zeroCount);
    in
    "${zeros}${numberString}";

  mkClientName = number: "${clientPrefix}${padNumber clientPadTo number}";
  clientNumbers = builtins.genList (number: number + 1) clientCount;
  clientHosts = map (number: {
    inherit number;
    name = mkClientName number;
    ip = "${networkBase}.${toString number}";
    profile = "client";
  }) clientNumbers;

  binaryCacheEnabled =
    if binaryCacheFeatureConfig ? enable then
      binaryCacheFeatureConfig.enable
    else
      true;
  homeResetEnabled =
    if homeResetFeatureConfig ? enable then
      homeResetFeatureConfig.enable
    else
      true;
  screensaverEnabled =
    if screensaverFeatureConfig ? enable then
      screensaverFeatureConfig.enable
    else
      true;
  veyonEnabled =
    if veyonFeatureConfig ? enable then
      veyonFeatureConfig.enable
    else
      true;
  guiBackendEnabled =
    if guiBackendFeatureConfig ? enable then
      guiBackendFeatureConfig.enable
    else
      true;
  guiBackendPort = guiBackendFeatureConfig.port or 8088;
  applianceEnabled =
    if applianceFeatureConfig ? enable then
      applianceFeatureConfig.enable
    else
      false;
  guiBackendRepoRoot =
    if guiBackendFeatureConfig ? repoRoot then
      guiBackendFeatureConfig.repoRoot
    else if applianceFeatureConfig ? repoRoot then
      applianceFeatureConfig.repoRoot
    else if applianceEnabled then
      "/var/lib/nixos-lab/repo"
    else
      "/home/${adminName}/nixos-lab";
  applianceRepoRoot = applianceFeatureConfig.repoRoot or guiBackendRepoRoot;
  applianceSeedOnBoot =
    if applianceFeatureConfig ? seedOnBoot then
      applianceFeatureConfig.seedOnBoot
    else
      applianceEnabled;

  normalizeExtraUser = user:
    let
      name =
        if user ? name then
          user.name
        else
          throw "Each extraUsers entry must define a name";
      passwordHash =
        if user ? passwordHash then
          user.passwordHash
        else
          throw "Extra user '${name}' must define passwordHash";
      extraGroups = user.extraGroups or [ "networkmanager" ];
      reservedGroups = [ "wheel" "veyon-master" "docker" ];
      invalidGroups = builtins.filter (group: builtins.elem group reservedGroups) extraGroups;
    in
    if name == "" then
      throw "Extra user names must not be empty"
    else if invalidGroups != [] then
      throw "Extra user '${name}' uses reserved groups: ${builtins.concatStringsSep ", " invalidGroups}"
    else
      {
        inherit name;
        inherit passwordHash;
        description = user.description or name;
        inherit extraGroups;
        sshKeys = user.sshKeys or [];
      };

  extraUsers = map normalizeExtraUser extraUsersConfig;

  coreNames = [
    adminName
    teacherName
    studentName
  ];
  allUserNames = coreNames ++ map (user: user.name) extraUsers;
  isValidUserName = name: builtins.match "^[a-z_][a-z0-9_-]*$" name != null;
  invalidUserNames = builtins.filter (name: !isValidUserName name) (lib.unique allUserNames);
  duplicateNames = builtins.filter (
    name:
      builtins.length (builtins.filter (candidate: candidate == name) allUserNames) > 1
  ) (lib.unique allUserNames);

  _ =
    if masterHostNumber <= clientCount then
      throw "masterHostNumber (${toString masterHostNumber}) must be greater than pcCount (${toString clientCount})"
    else if guiBackendRepoRoot == "" then
      throw "features.guiBackend.repoRoot must not be empty"
    else if builtins.length coreNames != builtins.length (lib.unique coreNames) then
      throw "Core user names must be unique"
    else if invalidUserNames != [] then
      throw "Invalid user names detected: ${builtins.concatStringsSep ", " invalidUserNames}"
    else if duplicateNames != [] then
      throw "Duplicate user names detected: ${builtins.concatStringsSep ", " (lib.unique duplicateNames)}"
    else
      null;

  labConfig = {
    schemaVersion = 1;
    network = {
      inherit (networkConfig) masterDhcpIp;
      inherit networkBase;
      inherit masterHostNumber;
      inherit (networkConfig) ifaceName;
      inherit cachePort;
      inherit pxeHttpPort;
    };
    hosts = {
      controller = {
        name = controllerName;
        number = masterHostNumber;
        ip = masterIp;
        profile = "controller";
      };
      clients = {
        count = clientCount;
        numbers = clientNumbers;
        profile = "client";
        naming = {
          prefix = clientPrefix;
          padTo = clientPadTo;
        };
        list = clientHosts;
      };
    };
    users = {
      admin = {
        name = adminName;
        passwordHash = adminPasswordHash;
        sshKeys = adminSshKeys;
      };
      teacher = {
        name = teacherName;
        passwordHash = teacherPasswordHash;
      };
      student = {
        name = studentName;
        passwordHash = studentPasswordHash;
        autologinOnClients = studentAutologinOnClients;
        resetHome = studentResetHome;
      };
      inherit extraUsers;
    };
    org = {
      homepageUrl = orgConfig.homepageUrl;
      git = {
        student = {
          name = orgConfig.git.student.name;
          email = orgConfig.git.student.email;
        };
        admin = {
          name = orgConfig.git.admin.name;
          email = orgConfig.git.admin.email;
        };
      };
    };
    locale = {
      inherit (localeConfig) timeZone;
      inherit (localeConfig) defaultLocale;
      inherit (localeConfig) extraLocale;
      inherit (localeConfig) keyboardLayout;
      inherit (localeConfig) consoleKeyMap;
    };
    software = {
      presets = softwarePresets;
      hostScopes = {
        controller = softwareControllerPresets;
        clients = softwareClientPresets;
      };
      extraPackages = softwareExtraPackages;
      desktop = {
        studentFavorites = softwareStudentFavorites;
        staffFavorites = softwareStaffFavorites;
      };
      vscode = {
        studentPresets = softwareStudentVscodePresets;
        adminPresets = softwareAdminVscodePresets;
      };
    };
    features = {
      binaryCache.enable = binaryCacheEnabled;
      homeReset.enable = homeResetEnabled;
      screensaver.enable = screensaverEnabled;
      veyon.enable = veyonEnabled;
      guiBackend = {
        enable = guiBackendEnabled;
        port = guiBackendPort;
        repoRoot = guiBackendRepoRoot;
      };
      appliance = {
        enable = applianceEnabled;
        repoRoot = applianceRepoRoot;
        seedOnBoot = applianceSeedOnBoot;
      };
    };
    keys = {
      inherit cachePublicKey;
      inherit adminPrimarySshKey;
      inherit adminSshKeys;
    };
  };

  labSettings = {
    inherit labConfig;
    inherit (labConfig) network;
    inherit (labConfig) hosts;
    inherit (labConfig) users;
    inherit (labConfig) org;
    inherit (labConfig) locale;
    inherit (labConfig) software;
    inherit (labConfig) features;
    inherit (labConfig) keys;
    masterIp = labConfig.hosts.controller.ip;
    masterDhcpIp = labConfig.network.masterDhcpIp;
    masterHostName = labConfig.hosts.controller.name;
    masterHostNumber = labConfig.hosts.controller.number;
    networkBase = labConfig.network.networkBase;
    pcCount = labConfig.hosts.clients.count;
    ifaceName = labConfig.network.ifaceName;
    teacherUser = labConfig.users.teacher.name;
    studentUser = labConfig.users.student.name;
    adminUser = labConfig.users.admin.name;
    teacherPassword = labConfig.users.teacher.passwordHash;
    studentPassword = labConfig.users.student.passwordHash;
    adminPassword = labConfig.users.admin.passwordHash;
    adminSshKey = labConfig.keys.adminPrimarySshKey;
    adminSshKeys = labConfig.keys.adminSshKeys;
    homepageUrl = labConfig.org.homepageUrl;
    studentGitName = labConfig.org.git.student.name;
    studentGitEmail = labConfig.org.git.student.email;
    adminGitName = labConfig.org.git.admin.name;
    adminGitEmail = labConfig.org.git.admin.email;
    timeZone = labConfig.locale.timeZone;
    defaultLocale = labConfig.locale.defaultLocale;
    extraLocale = labConfig.locale.extraLocale;
    keyboardLayout = labConfig.locale.keyboardLayout;
    consoleKeyMap = labConfig.locale.consoleKeyMap;
    cachePublicKey = labConfig.keys.cachePublicKey;
    cachePort = labConfig.network.cachePort;
    pxeHttpPort = labConfig.network.pxeHttpPort;
    extraUsers = labConfig.users.extraUsers;
  };

  labMeta = {
    schemaVersion = 1;
    controller = {
      name = labConfig.hosts.controller.name;
      number = labConfig.hosts.controller.number;
      staticIp = labConfig.hosts.controller.ip;
      dhcpIp = labConfig.network.masterDhcpIp;
    };
    clients = {
      count = labConfig.hosts.clients.count;
    };
    network = {
      base = labConfig.network.networkBase;
      inherit (labConfig.network) ifaceName;
      inherit (labConfig.network) cachePort;
      inherit (labConfig.network) pxeHttpPort;
    };
    services = {
      guiBackend = {
        enabled = labConfig.features.guiBackend.enable;
        host = "127.0.0.1";
        port = labConfig.features.guiBackend.port;
        repoRoot = labConfig.features.guiBackend.repoRoot;
      };
      appliance = {
        enabled = labConfig.features.appliance.enable;
        repoRoot = labConfig.features.appliance.repoRoot;
        seedOnBoot = labConfig.features.appliance.seedOnBoot;
      };
    };
    users = {
      admin = labConfig.users.admin.name;
      student = labConfig.users.student.name;
      teacher = labConfig.users.teacher.name;
      extraUsers = map (user: user.name) labConfig.users.extraUsers;
    };
  };
in
builtins.deepSeq _ {
  inherit labConfig;
  inherit labSettings;
  inherit labMeta;
}
