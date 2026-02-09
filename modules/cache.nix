{ labSettings, hostName, ... }:
let
  isMaster = hostName == labSettings.masterHostName;
in
{
  nix.settings = {
    # The master does not need itself as a substituter
    substituters = if isMaster then [] else [ "http://${labSettings.masterIp}:${toString labSettings.cachePort}" ];
    trusted-public-keys = [ labSettings.cachePublicKey ];
  };
}
