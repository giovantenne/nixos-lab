{ ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/users.nix
    # Add ./hardware-configuration.nix on pc02
  ];

  networking.hostName = "pc02";
}
