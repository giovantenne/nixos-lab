{ ... }:

{
  imports = [
    ./home-common.nix
  ];

  home.username = "informatica";
  home.homeDirectory = "/home/informatica";
  home.stateVersion = "25.11";
}
