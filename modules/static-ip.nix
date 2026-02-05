{ config, lib, ... }:

let
  # Extract PC number from hostname (e.g., "pc05" -> 5)
  pcNumber = lib.toInt (lib.removePrefix "pc" config.networking.hostName);
in
{
  networking.interfaces.enp0s3.ipv4.addresses = [
    {
      address = "10.22.9.${toString pcNumber}";
      prefixLength = 24;
    }
  ];
}
