{ hostIp, hostName, labSettings, ... }:
{
  networking.hostName = hostName;
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
