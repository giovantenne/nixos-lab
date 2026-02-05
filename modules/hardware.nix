{ modulesPath, lib, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Enable firmware for common hardware (Intel/AMD microcode, WiFi, etc.)
  hardware.enableRedistributableFirmware = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
