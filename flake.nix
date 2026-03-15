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
      cachePublicKeyFile = ./public-key;
      cachePublicKey =
        if builtins.pathExists cachePublicKeyFile then
          builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile cachePublicKeyFile)
        else
          null;
      adminSshKeyFile = ./id_ed25519.pub;
      adminSshKey =
        if builtins.pathExists adminSshKeyFile then
          builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile adminSshKeyFile)
        else
          null;
      veyonPublicKeyFile = ./veyon-public-key.pem;
      hasVeyonPublicKey = builtins.pathExists veyonPublicKeyFile;

      guiInstanceConfigFile = ./config/instance.json;
      rawConfig =
        if builtins.pathExists guiInstanceConfigFile then
          builtins.fromJSON (builtins.readFile guiInstanceConfigFile)
        else
          import ./lab-config.nix;
      normalizedConfig = import ./lib/normalize-config.nix {
        lib = nixpkgs.lib;
        inherit rawConfig;
        inherit cachePublicKey;
        inherit adminSshKey;
      };
      inherit (normalizedConfig) labConfig;
      inherit (normalizedConfig) labSettings;
      inherit (normalizedConfig) labMeta;
      sourceConfig = import ./lib/source-config.nix { inherit labConfig; };

      applianceRawConfig = nixpkgs.lib.recursiveUpdate rawConfig {
        features = {
          guiBackend = {
            repoRoot = "/var/lib/nixos-lab/repo";
          };
          appliance = {
            enable = true;
            repoRoot = "/var/lib/nixos-lab/repo";
            seedOnBoot = true;
          };
        };
      };
      applianceNormalizedConfig = import ./lib/normalize-config.nix {
        lib = nixpkgs.lib;
        rawConfig = applianceRawConfig;
        inherit cachePublicKey;
        inherit adminSshKey;
      };
      applianceLabConfig = applianceNormalizedConfig.labConfig;
      applianceLabSettings = applianceNormalizedConfig.labSettings;
      applianceSourceConfig = import ./lib/source-config.nix { labConfig = applianceLabConfig; };

      system = "x86_64-linux";
      controllerHost = labConfig.hosts.controller;
      clientHosts = labConfig.hosts.clients.list;

      # Overlay: packages not available in nixpkgs or needing patches
      labOverlay = final: prev: {
        veyon = final.callPackage ./pkgs/veyon.nix {};
        # gnome-remote-desktop with VNC enabled + multi-session patch
        gnome-remote-desktop = import ./pkgs/gnome-remote-desktop.nix { inherit prev; };
      };

      checkPkgs = import nixpkgs {
        inherit system;
        overlays = [ labOverlay ];
      };

      baseHostModules = [
        { nixpkgs.overlays = [ labOverlay ]; }
        ({ lib, ... }: {
          warnings =
            lib.optional (cachePublicKey == null) "Missing ./public-key. Generate it with: nix key convert-secret-to-public < secret-key > public-key"
            ++ lib.optional (adminSshKey == null) "Missing ./id_ed25519.pub. Generate it with: ssh-keygen -t ed25519 -f id_ed25519 -N '' -C 'admin@controller'"
            ++ lib.optional (!hasVeyonPublicKey) "Missing ./veyon-public-key.pem. Generate it with: openssl rsa -in veyon-private-key.pem -pubout -out veyon-public-key.pem";
        })
        disko.nixosModules.disko
        ./disko-uefi.nix
        ./modules/hardware.nix
        ./modules/base/common.nix
        ./modules/software/packages.nix
        ./modules/users
        ./modules/networking.nix
        ./modules/filesystems.nix
        ./modules/features/appliance-layout.nix
        ./modules/features/cache.nix
        ./modules/features/gui-backend.nix
        ./modules/features/home-reset.nix
        ./modules/features/screensaver.nix
        ./modules/features/veyon.nix
      ];

      profileModules = {
        controller = ./modules/profiles/controller.nix;
        client = ./modules/profiles/client.nix;
      };

      mkModules = host:
        baseHostModules ++ [
          profileModules.${host.profile}
        ];

      mkSpecialArgsFrom = config: settings: exportedSourceConfig: host: {
        labConfig = config;
        labSettings = settings;
        hostIp = host.ip;
        hostName = host.name;
        hostProfile = host.profile;
        flakeSource = self;
        applianceSourceConfig = exportedSourceConfig;
      };

      mkSpecialArgs = host: mkSpecialArgsFrom labConfig labSettings sourceConfig host;
      mkApplianceSpecialArgs = host: mkSpecialArgsFrom applianceLabConfig applianceLabSettings applianceSourceConfig host;

      mkHostFrom = specialArgsFor: host: {
        name = host.name;
        value = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = specialArgsFor host;
          modules = mkModules host;
        };
      };

      mkHost = host: mkHostFrom mkSpecialArgs host;

      mkColmenaHost = host: {
        name = host.name;
        value = {
          _module.args = mkSpecialArgs host;
          imports = mkModules host;
          deployment = {
            targetHost = host.ip;
            tags = [ "lab" ];
          };
        };
      };

      normalizeForTests = fixture:
        import ./lib/normalize-config.nix {
          lib = nixpkgs.lib;
          rawConfig = fixture;
          cachePublicKey = "lab-cache-key:test";
          adminSshKey = "ssh-ed25519 AAAATEST admin@test";
        };

      legacyFixture = import ./tests/fixtures/legacy-config.nix;
      legacyNormalized = normalizeForTests legacyFixture;
      applianceLegacyNormalized = import ./lib/normalize-config.nix {
        lib = nixpkgs.lib;
        rawConfig = nixpkgs.lib.recursiveUpdate legacyFixture {
          features = {
            appliance = {
              enable = true;
              repoRoot = "/var/lib/nixos-lab/repo";
              seedOnBoot = true;
            };
          };
        };
        cachePublicKey = "lab-cache-key:test";
        adminSshKey = "ssh-ed25519 AAAATEST admin@test";
      };
      conflictFixture = import ./tests/fixtures/conflict-extra-users.nix;
      conflictNormalization = builtins.tryEval (builtins.deepSeq (normalizeForTests conflictFixture) true);
    in
    {
      nixosConfigurations = builtins.listToAttrs (map mkHost clientHosts) // {
        ${controllerHost.name} = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = mkSpecialArgs controllerHost;
          modules = mkModules controllerHost;
        };
        controller-appliance = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = mkApplianceSpecialArgs controllerHost;
          modules = mkModules controllerHost;
        };
        controller-installer = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            labConfig = applianceLabConfig;
            labSettings = applianceLabSettings;
            flakeSource = self;
            applianceSourceConfig = applianceSourceConfig;
          };
          modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            ({ pkgs, lib, ... }:
              let
                installLabController = pkgs.writeShellScriptBin "install-lab-controller" ''
                  export FLAKE_REF='path:/installer/nixos-lab'
                  export DISKO_LAYOUT_PATH='/installer/nixos-lab/lib/disko-layout.nix'
                  export TARGET_HOST='controller-appliance'
                  exec ${pkgs.bash}/bin/bash /installer/nixos-lab/scripts/install-controller.sh "$@"
                '';
              in
              {
                networking.hostName = "controller-installer";
                environment.systemPackages = [
                  installLabController
                  disko.packages.${system}.default
                  pkgs.curl
                  pkgs.git
                  pkgs.jq
                ];
                system.stateVersion = "25.11";
                system.activationScripts.copyFlakeToInstaller.text = ''
                  install -d -m 0755 /installer
                  cp -a ${self}/. /installer/nixos-lab
                '';
                documentation.nixos.enable = false;
                image.baseName = lib.mkForce "nixos-lab-controller-installer";
                image.fileName = lib.mkForce "nixos-lab-controller-installer.iso";
              })
          ];
        };
        netboot = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit labConfig;
            inherit labSettings;
          };
          modules = [
            "${nixpkgs}/nixos/modules/installer/netboot/netboot-minimal.nix"
            ./modules/features/cache.nix
            ({ pkgs, lib, ... }: {
              # During netboot the master is only reachable on its DHCP address
              nix.settings.substituters = lib.mkForce [
                "http://${labConfig.network.masterDhcpIp}:${toString labSettings.cachePort}"
              ];
              networking.useDHCP = lib.mkForce true;
              services.openssh.enable = true;
              environment.systemPackages = [
                disko.packages.${system}.default
                pkgs.jq
              ];
              system.stateVersion = "25.11";
              system.activationScripts.copyFlakeToRamdisk.text = ''
                install -d -m 0755 /installer
                cp -a ${self}/. /installer/
              '';
            })
          ];
        };
      };

      inherit labMeta;

      checks.${system} = {
        normalize-config = checkPkgs.runCommand "normalize-config" {} ''
          test "${legacyNormalized.labSettings.adminUser}" = "labadmin"
          test "${legacyNormalized.labSettings.teacherUser}" = "teacher"
          test "${legacyNormalized.labSettings.studentUser}" = "student"
          test "${toString legacyNormalized.labSettings.pcCount}" = "3"
          test "${builtins.elemAt legacyNormalized.labMeta.users.extraUsers 0}" = "alice"
          test "${builtins.elemAt legacyNormalized.labConfig.software.presets 0}" = "base-cli"
          test "${builtins.elemAt legacyNormalized.labConfig.software.vscode.studentPresets 1}" = "java"
          test "${builtins.elemAt legacyNormalized.labConfig.software.desktop.studentFavorites 2}" = "code.desktop"
          test "${toString legacyNormalized.labConfig.features.guiBackend.port}" = "8088"
          test "${legacyNormalized.labConfig.features.guiBackend.repoRoot}" = "/home/labadmin/nixos-lab"
          test "${applianceLegacyNormalized.labConfig.features.appliance.repoRoot}" = "/var/lib/nixos-lab/repo"
          test "${if applianceLegacyNormalized.labConfig.features.appliance.enable then "true" else "false"}" = "true"
          touch "$out"
        '';

        validate-extra-users = checkPkgs.runCommand "validate-extra-users" {} ''
          test "${if conflictNormalization.success then "unexpected-success" else "failed-as-expected"}" = "failed-as-expected"
          touch "$out"
        '';
      };

      packages.${system} = {
        controller-installer = self.nixosConfigurations.controller-installer.config.system.build.isoImage;
      };

      colmena = {
        meta = {
          nixpkgs = import nixpkgs {
            inherit system;
            overlays = [ labOverlay ];
          };
          specialArgs = {
            inherit labConfig;
            inherit labSettings;
          };
        };
        defaults = {
          deployment = {
            targetUser = "root";
            buildOnTarget = false;
          };
        };
        # Controller deploys to itself locally
        ${controllerHost.name} = {
          _module.args = mkSpecialArgs controllerHost;
          imports = mkModules controllerHost;
          deployment = {
            targetHost = "localhost";
            tags = [ "master" ];
          };
        };
      } // builtins.listToAttrs (map mkColmenaHost clientHosts);
    };
}
