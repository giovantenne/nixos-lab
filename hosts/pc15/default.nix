{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/users.nix
  ];

  networking.hostName = "pc15";

  networking.interfaces.enp0s3 = {
    useDHCP = true;
  };
}
