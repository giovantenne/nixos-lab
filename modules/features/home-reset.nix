{ pkgs, labConfig, labSettings, lib, ... }:

let
  softwareCatalog = import ../../lib/software-catalog.nix {
    inherit lib;
    inherit pkgs;
  };
  gitConfigStudent = {
    name = labSettings.studentGitName;
    email = labSettings.studentGitEmail;
  };

  gitConfigAdmin = {
    name = labSettings.adminGitName;
    email = labSettings.adminGitEmail;
  };

  templateDirStudent = "/var/lib/home-template/${labSettings.studentUser}";
  templateDirAdmin = "/var/lib/home-template/${labSettings.adminUser}";
  snapshotsDir = "/var/lib/home-snapshots";
  homeDirStudent = "/home/${labSettings.studentUser}";
  homeDirAdmin = "/home/${labSettings.adminUser}";
  studentVscodeExtensions = softwareCatalog.resolveVscodeExtensionPresets labConfig.software.vscode.studentPresets;
  adminVscodeExtensions = softwareCatalog.resolveVscodeExtensionPresets labConfig.software.vscode.adminPresets;
  hasExtension = extensionDir: extensions:
    builtins.any (extension: extension.dir == extensionDir) extensions;
  copyVscodeExtensions = templateDir: extensions:
    if extensions == [] then
      ""
    else
      ''
        mkdir -p "${templateDir}/.vscode/extensions"
        ${builtins.concatStringsSep "\n      " (map (extension:
          ''cp -a "${extension.pkg}/share/vscode/extensions/${extension.dir}" "${templateDir}/.vscode/extensions/"''
        ) extensions)}
        # Fix Nix store read-only permissions so extensions can write temp files
        chmod -R u+w "${templateDir}/.vscode/extensions"
        ${if hasExtension "ritwickdey.liveserver" extensions then
          ''
            # Remove LiveServer announcement to suppress the "NEW" toast notification
            ${pkgs.jq}/bin/jq 'del(.announcement)' \
              "${templateDir}/.vscode/extensions/ritwickdey.liveserver/package.json" \
              > "${templateDir}/.vscode/extensions/ritwickdey.liveserver/package.json.tmp"
            mv "${templateDir}/.vscode/extensions/ritwickdey.liveserver/package.json.tmp" \
              "${templateDir}/.vscode/extensions/ritwickdey.liveserver/package.json"
          ''
        else
          ""}
      '';

  createTemplateScript = ../../scripts/create-home-template.sh;
  homeResetScript = ../../scripts/home-reset.sh;
  assetsDir = ../../assets;
in
lib.mkIf labConfig.features.homeReset.enable {
  # Ristretto wallpapers for random selection at home-reset
  environment.etc."lab/backgrounds/1-ristretto.jpg".source = ../../assets/backgrounds/1-ristretto.jpg;
  environment.etc."lab/backgrounds/2-ristretto.jpg".source = ../../assets/backgrounds/2-ristretto.jpg;
  environment.etc."lab/backgrounds/3-ristretto.jpg".source = ../../assets/backgrounds/3-ristretto.jpg;

  # Create templates at system activation (rebuild time)
  system.activationScripts.createHomeTemplates = {
    text = ''
      # Create student template
      ${pkgs.bash}/bin/bash ${createTemplateScript} "${templateDirStudent}" "${gitConfigStudent.name}" "${gitConfigStudent.email}" "${pkgs.xdg-user-dirs}/bin/xdg-user-dirs-update" "${assetsDir}"
      ${copyVscodeExtensions templateDirStudent studentVscodeExtensions}
      chown -R ${labSettings.studentUser}:users "${templateDirStudent}"

      # Create admin template
      ${pkgs.bash}/bin/bash ${createTemplateScript} "${templateDirAdmin}" "${gitConfigAdmin.name}" "${gitConfigAdmin.email}" "${pkgs.xdg-user-dirs}/bin/xdg-user-dirs-update" "${assetsDir}"
      ${copyVscodeExtensions templateDirAdmin adminVscodeExtensions}
      chown -R ${labSettings.adminUser}:users "${templateDirAdmin}"

      # Setup admin home (once, not reset at boot)
      if [ ! -f "${homeDirAdmin}/.home-initialized" ]; then
        cp -a "${templateDirAdmin}/." "${homeDirAdmin}/"
        chown -R ${labSettings.adminUser}:users "${homeDirAdmin}"
        touch "${homeDirAdmin}/.home-initialized"
      fi
    '';
    deps = [ "users" ];
  };

  # Systemd service to reset student home at boot
  systemd.services.home-reset = {
    description = "Reset ${labSettings.studentUser} home directory from template";
    wantedBy = [ "multi-user.target" ];
    before = [ "display-manager.service" ];
    after = [ "local-fs.target" ];
    unitConfig = {
      RequiresMountsFor = [
        "/home/${labSettings.studentUser}"
        "/var/lib/home-template"
        "/var/lib/home-snapshots"
      ];
    };
    path = [ pkgs.btrfs-progs pkgs.dconf pkgs.findutils pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${homeResetScript} ${snapshotsDir} ${homeDirStudent} ${templateDirStudent} ${labSettings.studentUser}:users";
      RemainAfterExit = true;
    };
  };

  # Ensure directories have correct permissions
  systemd.tmpfiles.rules = [
    "d /var/lib/home-snapshots 0750 root veyon-master -"
    "d /var/lib/home-template 0755 root root -"
  ];

  # Add "Snapshots" bookmark in Nautilus sidebar for teacher
  system.activationScripts.teacherSnapshotBookmark = {
    text = ''
      BOOKMARK_DIR="/home/${labSettings.teacherUser}/.config/gtk-3.0"
      BOOKMARK_FILE="$BOOKMARK_DIR/bookmarks"
      ENTRY="file:///var/lib/home-snapshots Snapshots"
      mkdir -p "$BOOKMARK_DIR"
      if ! grep -q "home-snapshots" "$BOOKMARK_FILE" 2>/dev/null; then
        echo "$ENTRY" >> "$BOOKMARK_FILE"
      fi
      chown -R ${labSettings.teacherUser}:users "$BOOKMARK_DIR"
    '';
    deps = [ "users" ];
  };
}
