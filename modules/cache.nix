{ labSettings, ... }:
{
  nix.settings = {
    substituters = [ "http://${labSettings.laptopIp}:${toString labSettings.cachePort}" ];
    trusted-public-keys = [ labSettings.cachePublicKey ];
  };
}
