{ labSettings, ... }:
{
  nix.settings = {
    substituters = [ "http://${labSettings.masterIp}:${toString labSettings.cachePort}" ];
    trusted-public-keys = [ labSettings.cachePublicKey ];
  };
}
