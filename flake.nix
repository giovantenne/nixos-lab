{
  description = "NixOS system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko }:
    let
      # ====== EDIT THESE ======
      # DHCP IP of pc31 (master controller)
      masterIp = "MASTER_IP";
      # Shared interface name on lab PCs
      ifaceName = "enp0s3";
      # =======================

      system = "x86_64-linux";
      pcNumbers = builtins.genList (n: n + 1) 31;
      clientNumbers = builtins.genList (n: n + 1) 30;
      padNumber = n: if n < 10 then "0${toString n}" else toString n;
      labSettings = {
        inherit masterIp;
        inherit ifaceName;
        cachePublicKey = "lab-cache-key:jJsA9nDLNlyzhBOj5rfSKcEL2IwNspxrbNCyqmvdUvI=";
        cachePort = 5000;
      };
      mkHost = n:
        let
          name = "pc${padNumber n}";
          hostIp = "10.22.9.${toString n}";
        in
        {
          inherit name;
          value = nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = {
              inherit labSettings;
              inherit hostIp;
              hostName = name;
            };
            modules = [
              disko.nixosModules.disko
              ./disko-bios.nix
              ./modules/hardware.nix
              ./modules/common.nix
              ./modules/users.nix
              ./modules/networking.nix
              ./modules/cache.nix
              ./modules/filesystems.nix
              ./modules/home-reset.nix
            ];
          };
        };
      mkColmenaHost = n:
        let
          name = "pc${padNumber n}";
          hostIp = "10.22.9.${toString n}";
          address = hostIp;
        in
        {
          inherit name;
          value = {
            specialArgs = {
              inherit labSettings;
              inherit hostIp;
              hostName = name;
            };
            imports = [
              disko.nixosModules.disko
              ./disko-bios.nix
              ./modules/hardware.nix
              ./modules/common.nix
              ./modules/users.nix
              ./modules/networking.nix
              ./modules/cache.nix
              ./modules/filesystems.nix
              ./modules/home-reset.nix
            ];
            deployment = {
              targetHost = address;
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
              environment.systemPackages = [ disko.packages.${system}.default ];
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
        # pc31 (master) deploys to itself locally
        pc31 = {
          specialArgs = {
            inherit labSettings;
            hostIp = "10.22.9.31";
            hostName = "pc31";
          };
          imports = [
            disko.nixosModules.disko
            ./disko-bios.nix
            ./modules/hardware.nix
            ./modules/common.nix
            ./modules/users.nix
            ./modules/networking.nix
            ./modules/cache.nix
            ./modules/filesystems.nix
            ./modules/home-reset.nix
          ];
          deployment = {
            targetHost = "localhost";
            tags = [ "master" ];
          };
        };
      } // builtins.listToAttrs (map mkColmenaHost clientNumbers);
    };
}
