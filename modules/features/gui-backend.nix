{ lib, pkgs, labConfig, hostProfile, ... }:

let
  isController = hostProfile == "controller";
  guiPort = toString labConfig.features.guiBackend.port;
  repoRoot = labConfig.features.guiBackend.repoRoot;
  stateDir = "/var/lib/lab-gui";
  pythonEnv = pkgs.python3.withPackages (pythonPackages: [
    pythonPackages.fastapi
    pythonPackages.jinja2
    pythonPackages.pydantic
    pythonPackages.uvicorn
  ]);
  openLabGui = pkgs.writeShellScriptBin "lab-gui" ''
    exec ${pkgs.xdg-utils}/bin/xdg-open "http://127.0.0.1:${guiPort}"
  '';
  manageLabGuiConfig = pkgs.writeShellScriptBin "lab-gui-config" ''
    export LAB_GUI_REPO_ROOT='${repoRoot}'
    export LAB_GUI_STATE_DIR='${stateDir}'
    export LAB_GUI_INSTANCE_CONFIG='${repoRoot}/config/instance.json'
    export LAB_GUI_VALIDATE_NIX='${repoRoot}/scripts/gui/validate-instance.nix'
    exec ${pkgs.bash}/bin/bash ${../../scripts/gui/manage-instance-config.sh} "$@"
  '';
  labGuiDesktop = pkgs.makeDesktopItem {
    name = "lab-gui";
    desktopName = "NixOS Lab Control";
    exec = "lab-gui";
    icon = "preferences-system";
    terminal = false;
    categories = [
      "System"
      "Settings"
    ];
    comment = "Open the local lab management dashboard";
  };
in
lib.mkIf (isController && labConfig.features.guiBackend.enable) {
  environment.systemPackages = [
    openLabGui
    manageLabGuiConfig
    labGuiDesktop
  ];

  systemd.tmpfiles.rules = [
    "d ${stateDir} 2770 root wheel -"
    "d ${stateDir}/backups 2770 root wheel -"
    "d ${stateDir}/jobs 2770 root wheel -"
  ];

  systemd.services.lab-gui-backend = {
    description = "Lab GUI backend";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.colmena
      pkgs.git
      pkgs.nix
      pkgs.openssl
    ];
    environment = {
      LAB_GUI_HOST = "127.0.0.1";
      LAB_GUI_PORT = guiPort;
      LAB_GUI_REPO_ROOT = repoRoot;
      LAB_GUI_STATE_DIR = stateDir;
      LAB_GUI_INSTANCE_CONFIG = "${repoRoot}/config/instance.json";
      LAB_GUI_EXPORT_NIX = "${repoRoot}/scripts/gui/export-source-config.nix";
      LAB_GUI_VALIDATE_NIX = "${repoRoot}/scripts/gui/validate-instance.nix";
    };
    unitConfig = {
      ConditionPathExists = "${repoRoot}/flake.nix";
    };
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pythonEnv}/bin/python ${../../scripts/gui/backend.py}";
      WorkingDirectory = repoRoot;
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
