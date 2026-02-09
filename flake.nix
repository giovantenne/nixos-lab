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
      # Controller host settings
      networkBase = "10.22.9";
      pcCount = 30;
      masterHostNumber = 99;
      masterHostName = "pc${toString masterHostNumber}";
      masterIp = "${networkBase}.${toString masterHostNumber}";
      # Shared interface name on lab PCs
      ifaceName = "enp0s3";
      # =======================

      system = "x86_64-linux";
      pcNumbers = builtins.genList (n: n + 1) pcCount;
      clientNumbers = pcNumbers;
      padNumber = n: if n < 10 then "0${toString n}" else toString n;

      # Overlay: packages not available in nixpkgs or needing patches
      labOverlay = final: prev: {
        veyon = final.callPackage ./pkgs/veyon.nix {};
        # gnome-remote-desktop with VNC enabled + multi-session patch
        gnome-remote-desktop = import ./pkgs/gnome-remote-desktop.nix { inherit prev; };
      };

      hostModules = [
        { nixpkgs.overlays = [ labOverlay ]; }
        disko.nixosModules.disko
        ./disko-bios.nix
        ./modules/hardware.nix
        ./modules/common.nix
        ./modules/users.nix
        ./modules/networking.nix
        ./modules/cache.nix
        ./modules/filesystems.nix
        ./modules/home-reset.nix
        ./modules/veyon.nix
      ];

      labSettings = {
        inherit masterIp;
        inherit masterHostName;
        inherit networkBase;
        inherit pcCount;
        inherit ifaceName;
        cachePublicKey = "lab-cache-key:jJsA9nDLNlyzhBOj5rfSKcEL2IwNspxrbNCyqmvdUvI=";
        cachePort = 5000;
      };
      mkHost = n:
        let
          name = "pc${padNumber n}";
          hostIp = "${networkBase}.${toString n}";
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
            modules = hostModules;
          };
        };
      mkColmenaHost = n:
        let
          name = "pc${padNumber n}";
          hostIp = "${networkBase}.${toString n}";
          address = hostIp;
        in
        {
          inherit name;
          value = {
            _module.args = {
              inherit labSettings;
              inherit hostIp;
              hostName = name;
            };
            imports = hostModules;
            deployment = {
              targetHost = address;
              tags = [ "lab" ];
            };
          };
        };
    in
    {
      nixosConfigurations = builtins.listToAttrs (map mkHost pcNumbers) // {
        ${masterHostName} = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit labSettings;
            hostIp = masterIp;
            hostName = masterHostName;
          };
          modules = hostModules;
        };
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
          nixpkgs = import nixpkgs {
            inherit system;
            overlays = [ labOverlay ];
          };
          specialArgs = { inherit labSettings; };
        };
        defaults = {
          deployment = {
            targetUser = "root";
            buildOnTarget = false;
          };
        };
        # pc99 (master) deploys to itself locally
        ${masterHostName} = {
          _module.args = {
            inherit labSettings;
            hostIp = masterIp;
            hostName = masterHostName;
          };
          imports = hostModules;
          deployment = {
            targetHost = "localhost";
            tags = [ "master" ];
          };
        };
      } // builtins.listToAttrs (map mkColmenaHost clientNumbers);
    };
}
