{ config, pkgs, lib, ... }:

let
  # VS Code extensions to install in template
  vscodeExtensions = [
    "vscjava.vscode-java-pack"
    "ritwickdey.liveserver"
  ];

  # Git configuration
  gitConfigInformatica = {
    name = "studente";
    email = "studente@itismeucci.com";
  };

  gitConfigAdmin = {
    name = "admin";
    email = "admin@itismeucci.com";
  };

  templateDirInformatica = "/var/lib/home-template/informatica";
  templateDirAdmin = "/var/lib/home-template/admin";
  snapshotsDir = "/var/lib/home-snapshots";
  homeDirInformatica = "/home/informatica";
  homeDirAdmin = "/home/admin";

  # External scripts
  createTemplateScript = ../assets/create-home-template.sh;
  homeResetScript = ../assets/home-reset.sh;
  installExtensionsScript = ../assets/install-vscode-extensions.sh;
  assetsDir = ../assets;

  extensionsList = lib.concatStringsSep " " vscodeExtensions;

in
{
  # Create templates at system activation (rebuild time)
  system.activationScripts.createHomeTemplates = {
    text = ''
      # Create informatica template
      ${pkgs.bash}/bin/bash ${createTemplateScript} "${templateDirInformatica}" "${gitConfigInformatica.name}" "${gitConfigInformatica.email}" "${pkgs.xdg-user-dirs}/bin/xdg-user-dirs-update" "${assetsDir}"
      ${pkgs.bash}/bin/bash ${installExtensionsScript} "${templateDirInformatica}/.vscode/extensions" "${pkgs.vscode}/bin/code" ${extensionsList}
      chown -R informatica:users "${templateDirInformatica}"

      # Create admin template
      ${pkgs.bash}/bin/bash ${createTemplateScript} "${templateDirAdmin}" "${gitConfigAdmin.name}" "${gitConfigAdmin.email}" "${pkgs.xdg-user-dirs}/bin/xdg-user-dirs-update" "${assetsDir}"
      ${pkgs.bash}/bin/bash ${installExtensionsScript} "${templateDirAdmin}/.vscode/extensions" "${pkgs.vscode}/bin/code" ${extensionsList}
      chown -R admin:users "${templateDirAdmin}"

      # Setup admin home (once, not reset at boot)
      if [ ! -f "/home/admin/.home-initialized" ]; then
        cp -a "${templateDirAdmin}/." "/home/admin/"
        chown -R admin:users "/home/admin"
        touch "/home/admin/.home-initialized"
      fi
    '';
    deps = [ "users" ];
  };

  # Systemd service to reset informatica home at boot
  systemd.services.home-reset = {
    description = "Reset informatica home directory from template";
    wantedBy = [ "multi-user.target" ];
    before = [ "display-manager.service" ];
    after = [ "local-fs.target" ];
    path = [ pkgs.btrfs-progs pkgs.findutils pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${homeResetScript} ${snapshotsDir} ${homeDirInformatica} ${templateDirInformatica}";
      RemainAfterExit = true;
    };
  };

  # Ensure directories have correct permissions
  systemd.tmpfiles.rules = [
    "d /var/lib/home-snapshots 0700 root root -"
    "d /var/lib/home-template 0755 root root -"
  ];
}
