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
  btrfsDevice = "/dev/disk/by-label/nixos";

  # Script to download and install VS Code extensions into template
  installExtensionsScript = pkgs.writeShellScript "install-vscode-extensions" ''
    set -euo pipefail
    EXTENSIONS_DIR="${templateDir}/.vscode/extensions"
    mkdir -p "$EXTENSIONS_DIR"
    
    ${lib.concatMapStringsSep "\n" (ext: ''
      echo "Installing extension: ${ext}"
      # Use VS Code CLI to download extension
      ${pkgs.vscode}/bin/code --extensions-dir "$EXTENSIONS_DIR" --install-extension ${ext} --force || true
    '') vscodeExtensions}
    
    # Fix permissions
    chown -R informatica:users "${templateDir}/.vscode"
  '';

  # Script to create home template
  createTemplateScript = pkgs.writeShellScript "create-home-template" ''
    set -euo pipefail
    
    echo "Creating home template..."
    
    # Create template directory
    mkdir -p "${templateDir}"
    
    # Create .gitconfig
    cat > "${templateDir}/.gitconfig" << 'EOF'
    [user]
        name = ${gitConfig.name}
        email = ${gitConfig.email}
    EOF
    
    # Create basic directories
    mkdir -p "${templateDir}/Documenti"
    mkdir -p "${templateDir}/Progetti"
    mkdir -p "${templateDir}/.config"
    mkdir -p "${templateDir}/.local/share"
    
    # Install VS Code extensions
    ${installExtensionsScript}
    
    # Set ownership
    chown -R informatica:users "${templateDir}"
    
    echo "Home template created successfully"
  '';

  # Script to reset home at boot
  homeResetScript = pkgs.writeShellScript "home-reset" ''
    set -euo pipefail
    
    echo "Starting home reset..."
    
    SNAPSHOTS_DIR="${snapshotsDir}"
    HOME_DIR="${homeDir}"
    TEMPLATE_DIR="${templateDir}"
    BTRFS_DEVICE="${btrfsDevice}"
    
    # Ensure snapshots directory exists
    mkdir -p "$SNAPSHOTS_DIR"
    
    # Check if home has any content (not first boot)
    if [ "$(ls -A $HOME_DIR 2>/dev/null)" ]; then
      echo "Rotating snapshots..."
      
      # Remove oldest snapshot (5)
      if [ -d "$SNAPSHOTS_DIR/snapshot-5" ]; then
        btrfs subvolume delete "$SNAPSHOTS_DIR/snapshot-5" || rm -rf "$SNAPSHOTS_DIR/snapshot-5"
      fi
      
      # Rotate snapshots: 4->5, 3->4, 2->3, 1->2
      for i in 4 3 2 1; do
        next=$((i + 1))
        if [ -d "$SNAPSHOTS_DIR/snapshot-$i" ]; then
          mv "$SNAPSHOTS_DIR/snapshot-$i" "$SNAPSHOTS_DIR/snapshot-$next"
        fi
      done
      
      # Create new snapshot of current home
      echo "Creating snapshot of current home..."
      btrfs subvolume snapshot -r "$HOME_DIR" "$SNAPSHOTS_DIR/snapshot-1" || \
        cp -a "$HOME_DIR" "$SNAPSHOTS_DIR/snapshot-1"
    fi
    
    # Clear home directory content (keep the subvolume mount)
    echo "Clearing home directory..."
    find "$HOME_DIR" -mindepth 1 -delete 2>/dev/null || true
    
    # Copy template to home
    echo "Copying template to home..."
    if [ -d "$TEMPLATE_DIR" ]; then
      cp -a "$TEMPLATE_DIR/." "$HOME_DIR/"
    fi
    
    # Ensure correct ownership
    chown -R informatica:users "$HOME_DIR"
    chmod 755 "$HOME_DIR"
    
    echo "Home reset completed"
  '';

in
{
  # Create template at system activation (rebuild time)
  system.activationScripts.createHomeTemplate = {
    text = ''
      ${createTemplateScript}
    '';
    deps = [ "users" ];
  };

  # Systemd service to reset home at boot
  systemd.services.home-reset = {
    description = "Reset informatica home directory from template";
    wantedBy = [ "multi-user.target" ];
    before = [ "display-manager.service" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = homeResetScript;
      RemainAfterExit = true;
    };
  };

  # Ensure snapshots directory has correct permissions (only root can access)
  systemd.tmpfiles.rules = [
    "d /var/lib/home-snapshots 0700 root root -"
    "d /var/lib/home-template 0755 root root -"
  ];
}
