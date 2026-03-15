{ lib, pkgs, labConfig, hostProfile, ... }:

let
  softwareCatalog = import ../../lib/software-catalog.nix {
    inherit lib;
    inherit pkgs;
  };

  scopedPresets =
    if hostProfile == "controller" then
      labConfig.software.hostScopes.controller
    else if hostProfile == "client" then
      labConfig.software.hostScopes.clients
    else
      throw "Unknown hostProfile '${hostProfile}' for software assembly";

  resolvedSoftware = softwareCatalog.resolvePresets (labConfig.software.presets ++ scopedPresets);
  extraPackages = softwareCatalog.resolveExtraPackages labConfig.software.extraPackages;
in
{
  programs.firefox.enable = resolvedSoftware.enableFirefox;
  programs.neovim.enable = resolvedSoftware.enableNeovim;
  virtualisation.docker.enable = resolvedSoftware.enableDocker;

  environment.systemPackages = resolvedSoftware.packages ++ extraPackages;
}
