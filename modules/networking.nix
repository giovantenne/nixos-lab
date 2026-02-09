{ hostIp, hostName, labSettings, ... }:
{
  networking.hostName = hostName;
  networking.networkmanager.unmanaged = [ "interface-name:${labSettings.ifaceName}" ];
  networking.interfaces = {
    ${labSettings.ifaceName} = {
      useDHCP = true;
      ipv4.addresses = [
        {
          address = hostIp;
          prefixLength = 24;
        }
      ];
    };
  };
}
