{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/users.nix
  ];

  networking.hostName = "pc16";

  networking.interfaces.enp0s3 = {
    useDHCP = true;
  };
}
