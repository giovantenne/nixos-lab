{ lib, pkgs, labConfig, hostProfile, flakeSource, applianceSourceConfig, ... }:

let
  isController = hostProfile == "controller";
  applianceEnabled = labConfig.features.appliance.enable;
  seedOnBoot = labConfig.features.appliance.seedOnBoot;
  repoRoot = labConfig.features.appliance.repoRoot;
  sourceConfigFile = pkgs.writeText "lab-appliance-instance.json" (builtins.toJSON applianceSourceConfig);
  seedRepoCommand = pkgs.writeShellScriptBin "lab-appliance-seed-repo" ''
    export LAB_APPLIANCE_SOURCE_REPO='${flakeSource}'
    export LAB_APPLIANCE_REPO_ROOT='${repoRoot}'
    export LAB_APPLIANCE_SOURCE_CONFIG_PATH='${sourceConfigFile}'
    exec ${pkgs.bash}/bin/bash ${../../scripts/appliance-seed-repo.sh}
  '';
in
lib.mkIf (isController && applianceEnabled) {
  environment.systemPackages = [ seedRepoCommand ];

  systemd.services.lab-appliance-seed-repo = lib.mkIf seedOnBoot {
    description = "Seed appliance repo into the fixed controller path";
    wantedBy = [ "multi-user.target" ];
    before = [ "lab-gui-backend.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${seedRepoCommand}/bin/lab-appliance-seed-repo";
      RemainAfterExit = true;
    };
  };

  systemd.services.lab-gui-backend = lib.mkIf labConfig.features.guiBackend.enable {
    after = [ "lab-appliance-seed-repo.service" ];
    requires = lib.mkIf seedOnBoot [ "lab-appliance-seed-repo.service" ];
  };
}
