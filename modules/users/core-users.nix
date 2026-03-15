{ hostName, labConfig, labSettings, ... }:

let
  adminUser = labConfig.users.admin;
  teacherUser = labConfig.users.teacher;
  studentUser = labConfig.users.student;
  isMaster = hostName == labSettings.masterHostName;
in
{
  # Passwords are managed declaratively, cannot be changed manually
  users.mutableUsers = false;
  users.groups.veyon-master = {};

  # Disable root password login
  users.users.root = {
    hashedPassword = "!";
    openssh.authorizedKeys.keys = adminUser.sshKeys;
  };

  users.users.${teacherUser.name} = {
    isNormalUser = true;
    description = teacherUser.name;
    extraGroups = [ "networkmanager" "docker" "veyon-master" ];
    hashedPassword = teacherUser.passwordHash;
  };

  users.users.${studentUser.name} = {
    isNormalUser = true;
    description = studentUser.name;
    extraGroups = [ "networkmanager" "docker" "render" "video" ];
    hashedPassword = studentUser.passwordHash;
  };

  users.users.${adminUser.name} = {
    isNormalUser = true;
    description = adminUser.name;
    extraGroups = [ "networkmanager" "wheel" "docker" "veyon-master" ];
    hashedPassword = adminUser.passwordHash;
    openssh.authorizedKeys.keys = adminUser.sshKeys;
  };

  services.displayManager.autoLogin = {
    enable = !isMaster && studentUser.autologinOnClients;
    user = studentUser.name;
  };
}
