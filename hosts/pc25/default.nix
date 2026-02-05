{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/users.nix
  ];

  networking.hostName = "pc25";

  networking.interfaces.enp0s3 = {
    useDHCP = true;
  };
}
