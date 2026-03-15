{ config, labConfig, labSettings, lib, ... }:

let
  isMaster = config.networking.hostName == labSettings.masterHostName;
in
lib.mkIf labConfig.features.binaryCache.enable {
  nix.settings = {
    # The master does not need itself as a substituter
    substituters = if isMaster then [] else [ "http://${labSettings.masterIp}:${toString labSettings.cachePort}" ];
    trusted-public-keys = if labSettings.cachePublicKey == null then [] else [ labSettings.cachePublicKey ];
  };
}
