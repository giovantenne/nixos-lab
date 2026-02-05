{ ... }:
{
  imports = [
    ../../modules/hardware.nix
    ../../modules/common.nix
    ../../modules/users.nix
  ];

  networking.hostName = "pc21";

  networking.interfaces.enp0s3 = {
    useDHCP = true;
  };

  networking.interfaces.enp0s3.ipv4.addresses = [
    {
      address = "10.22.9.21";
      prefixLength = 24;
    }
  ];
}
