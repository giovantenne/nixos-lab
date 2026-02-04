{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ ];

  # TODO: Generate this file on the actual PC with:
  # sudo nixos-generate-config --root /mnt
  # Then copy the hardware-configuration.nix here

  boot.initrd.availableKernelModules = [ ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];


  swapDevices = [ ];
}
