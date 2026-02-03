{
  description = "NixOS system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager }:
    let
      pcNumbers = builtins.genList (n: n + 1) 31;
      padNumber = n: if n < 10 then "0${toString n}" else toString n;
      mkHost = n:
        let name = "pc${padNumber n}";
        in {
          inherit name;
          value = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              ./hosts/${name}/default.nix
              home-manager.nixosModules.home-manager
            ];
          };
        };
    in
    {
      nixosConfigurations = builtins.listToAttrs (map mkHost pcNumbers);
    };
}
