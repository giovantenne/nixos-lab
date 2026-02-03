{ ... }:

{
  imports = [
    ./home-common.nix
  ];

  home.username = "admin";
  home.homeDirectory = "/home/admin";
  home.stateVersion = "25.11";
}
