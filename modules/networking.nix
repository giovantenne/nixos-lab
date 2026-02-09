{ hostIp, hostName, labSettings, ... }:
{
  networking.hostName = hostName;
  networking.networkmanager.ensureProfiles = {
    lab = {
      connection = {
        id = "lab";
        type = "ethernet";
        interface-name = labSettings.ifaceName;
        autoconnect = true;
      };
      ipv4 = {
        method = "auto";
        addresses = [ "${hostIp}/24" ];
      };
      ipv6 = {
        method = "auto";
      };
    };
  };
}
