{ config, pkgs, lib, ... }:

let
  # VS Code extensions to install in template
  vscodeExtensions = [
    "vscjava.vscode-java-pack"
    "ritwickdey.liveserver"
  ];

  # Git configuration for students
  gitConfig = {
    name = "studente";
    email = "studente@itismeucci.com";
  };

  templateDir = "/var/lib/home-template/informatica";
  snapshotsDir = "/var/lib/home-snapshots";
  homeDir = "/home/informatica";

  # External scripts
  createTemplateScript = ../assets/create-home-template.sh;
  homeResetScript = ../assets/home-reset.sh;
  installExtensionsScript = ../assets/install-vscode-extensions.sh;
  assetsDir = ../assets;

  extensionsList = lib.concatStringsSep " " vscodeExtensions;

in
{
  # Create template at system activation (rebuild time)
  system.activationScripts.createHomeTemplate = {
    text = ''
      # Create base template
      ${pkgs.bash}/bin/bash ${createTemplateScript} "${templateDir}" "${gitConfig.name}" "${gitConfig.email}" "${pkgs.xdg-user-dirs}/bin/xdg-user-dirs-update" "${assetsDir}" "${pkgs.dconf}/bin/dconf"
      
      # Install VS Code extensions
      ${pkgs.bash}/bin/bash ${installExtensionsScript} "${templateDir}/.vscode/extensions" "${pkgs.vscode}/bin/code" ${extensionsList}
      
      # Fix ownership
      chown -R informatica:users "${templateDir}"
    '';
    deps = [ "users" ];
  };

  # Systemd service to reset home at boot
  systemd.services.home-reset = {
    description = "Reset informatica home directory from template";
    wantedBy = [ "multi-user.target" ];
    before = [ "display-manager.service" ];
    after = [ "local-fs.target" ];
    path = [ pkgs.btrfs-progs pkgs.findutils pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${homeResetScript} ${snapshotsDir} ${homeDir} ${templateDir}";
      RemainAfterExit = true;
    };
  };

  # Ensure snapshots directory has correct permissions (only root can access)
  systemd.tmpfiles.rules = [
    "d /var/lib/home-snapshots 0700 root root -"
    "d /var/lib/home-template 0755 root root -"
  ];
}
