{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/users.nix
  ];

  networking.hostName = "pc18";

  networking.interfaces.enp0s3 = {
    useDHCP = true;
  };
}
