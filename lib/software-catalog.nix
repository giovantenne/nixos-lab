{ lib, pkgs }:

let
  catalog = {
    base-cli = {
      packages = [
        pkgs.wget
        pkgs.curl
        pkgs.openssl
        pkgs.bat
        pkgs.bash-completion
        pkgs.eza
        pkgs.fd
        pkgs.fzf
        pkgs.git
        pkgs.jq
        pkgs.lazygit
        pkgs.ripgrep
        pkgs.try
        pkgs.unzip
        pkgs.xdg-user-dirs
      ];
    };
    desktop = {
      packages = [
        pkgs.ghostty
        pkgs.chromium
        pkgs.vscode
        pkgs.gnomeExtensions.desktop-icons-ng-ding
        pkgs.gnomeExtensions.dash-to-dock
        pkgs.yaru-theme
      ];
    };
    dev-tools = {
      packages = [
        pkgs.gcc
        pkgs.tig
        pkgs.tmux
        pkgs.opencode
      ];
    };
    container = {
      packages = [ pkgs.docker-compose ];
      enableDocker = true;
    };
    publishing = {
      packages = [
        pkgs.imagemagick
        pkgs.ghostscript
        pkgs.tectonic
        pkgs.mermaid-cli
      ];
    };
    python = {
      packages = [
        pkgs.python3
        pkgs.python3Packages.pip
        pkgs.python3Packages.terminaltexteffects
        pkgs.python3Packages.virtualenv
      ];
    };
    lua = {
      packages = [
        pkgs.luarocks
        pkgs.lua-language-server
      ];
    };
    java = {
      packages = [
        pkgs.jdk21
        pkgs.maven
      ];
    };
    node = {
      packages = [ pkgs.nodejs_20 ];
    };
    php = {
      packages = [ pkgs.php83 ];
    };
    browser = {
      enableFirefox = true;
    };
    editor = {
      enableNeovim = true;
    };
    network-admin = {
      packages = [ pkgs.dnsmasq ];
    };
  };

  vscodeExtensionPresets = {
    web = [
      {
        pkg = pkgs.vscode-extensions.ritwickdey.liveserver;
        dir = "ritwickdey.liveserver";
      }
    ];
    java = [
      {
        pkg = pkgs.vscode-extensions.vscjava.vscode-java-pack;
        dir = "vscjava.vscode-java-pack";
      }
      {
        pkg = pkgs.vscode-extensions.redhat.java;
        dir = "redhat.java";
      }
      {
        pkg = pkgs.vscode-extensions.vscjava.vscode-java-debug;
        dir = "vscjava.vscode-java-debug";
      }
      {
        pkg = pkgs.vscode-extensions.vscjava.vscode-java-test;
        dir = "vscjava.vscode-java-test";
      }
      {
        pkg = pkgs.vscode-extensions.vscjava.vscode-maven;
        dir = "vscjava.vscode-maven";
      }
      {
        pkg = pkgs.vscode-extensions.vscjava.vscode-java-dependency;
        dir = "vscjava.vscode-java-dependency";
      }
    ];
  };

  emptySelection = {
    packages = [];
    enableDocker = false;
    enableFirefox = false;
    enableNeovim = false;
  };

  validateNames = known: kind: names:
    let
      unknownNames = builtins.filter (name: !builtins.hasAttr name known) names;
    in
    if unknownNames != [] then
      throw "Unknown ${kind}: ${builtins.concatStringsSep ", " unknownNames}"
    else
      names;

  mergeSelection = selection: item:
    selection
    // {
      packages = selection.packages ++ (item.packages or []);
      enableDocker = selection.enableDocker || (item.enableDocker or false);
      enableFirefox = selection.enableFirefox || (item.enableFirefox or false);
      enableNeovim = selection.enableNeovim || (item.enableNeovim or false);
    };
in
{
  inherit catalog;
  inherit vscodeExtensionPresets;

  resolvePresets = presetNames:
    let
      resolvedNames = validateNames catalog "software preset" presetNames;
      selection = builtins.foldl' (
        acc: presetName:
          mergeSelection acc (builtins.getAttr presetName catalog)
      ) emptySelection resolvedNames;
    in
    selection // {
      packages = lib.unique selection.packages;
    };

  resolveExtraPackages = packageNames:
    let
      unknownNames = builtins.filter (name: !builtins.hasAttr name pkgs) packageNames;
    in
    if unknownNames != [] then
      throw "Unknown extra package names: ${builtins.concatStringsSep ", " unknownNames}"
    else
      map (name: builtins.getAttr name pkgs) packageNames;

  resolveVscodeExtensionPresets = presetNames:
    let
      resolvedNames = validateNames vscodeExtensionPresets "VS Code extension preset" presetNames;
    in
    lib.unique (builtins.concatLists (map (name: builtins.getAttr name vscodeExtensionPresets) resolvedNames));
}
