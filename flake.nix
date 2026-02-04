{
  description = "NixOS system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pcNumbers = builtins.genList (n: n + 1) 31;
      padNumber = n: if n < 10 then "0${toString n}" else toString n;
      labSettings = {
        masterIp = "MASTER_IP";  # Replace with actual IP before building netboot
        cachePublicKey = "lab-cache-key:jJsA9nDLNlyzhBOj5rfSKcEL2IwNspxrbNCyqmvdUvI=";
        cachePort = 8080;
      };
      mkHost = n:
        let name = "pc${padNumber n}";
        in {
          inherit name;
          value = nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = { inherit labSettings; };
            modules = [
              ./hosts/${name}/default.nix
              ./modules/cache.nix
              ./modules/filesystems.nix
              ./modules/home-reset.nix
            ];
          };
        };
      mkColmenaHost = n:
        let
          name = "pc${padNumber n}";
          address = "10.22.9.${toString n}";
        in
        {
          inherit name;
          value = {
            imports = [
              ./hosts/${name}/default.nix
              ./modules/cache.nix
              ./modules/filesystems.nix
              ./modules/home-reset.nix
            ];
            deployment = {
              targetHost = address;
              targetUser = "root";
              buildOnTarget = false;
              tags = [ "lab" ];
            };
          };
        };
    in
    {
      nixosConfigurations = builtins.listToAttrs (map mkHost pcNumbers) // {
        netboot = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit labSettings; };
          modules = [
            "${nixpkgs}/nixos/modules/installer/netboot/netboot-minimal.nix"
            ./modules/cache.nix
            ({ pkgs, lib, ... }: {
              networking.useDHCP = lib.mkForce true;
              services.openssh.enable = true;
              system.stateVersion = "25.11";
              system.activationScripts.copyFlakeToRamdisk.text = ''
                install -d -m 0755 /installer/repo
                cp -a ${self}/. /installer/repo/
              '';
            })
          ];
        };
      };

      colmena = {
        meta = {
          nixpkgs = import nixpkgs { inherit system; };
          specialArgs = { inherit labSettings; };
        };
        defaults = {
          deployment = {
            targetUser = "root";
            buildOnTarget = false;
          };
        };
      } // builtins.listToAttrs (map mkColmenaHost pcNumbers);
    };
}
