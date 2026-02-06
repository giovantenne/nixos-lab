{ hostIp, hostName, labSettings, ... }:
{
  networking.hostName = hostName;
  networking.interfaces.${labSettings.ifaceName} = {
    useDHCP = true;
  };
  networking.interfaces.${labSettings.ifaceName}.ipv4.addresses = [
    {
      address = hostIp;
      prefixLength = 24;
    }
  ];
}
