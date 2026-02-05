{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/users.nix
  ];

  networking.hostName = "pc21";

  networking.interfaces.enp0s3 = {
    useDHCP = true;
  };
}
