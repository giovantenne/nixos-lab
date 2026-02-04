# NixOS Lab Deployment (Zero-Internet Workflow)
This repository manages a 31-PC NixOS lab, optimized for network installation (Netboot) with no internet access and a master PC (`pc31`) acting as the local controller.

## Architecture
- Controller (`pc31`): `PXE/Netboot`, local `binary cache`, `Colmena` orchestration.
- Nodes (Lab PCs): 30 workstations with `Btrfs` + `Impermanence` (root reset on every reboot).
- Networking: installs and updates over `LAN` only, no internet on client PCs.

## 1. First setup at school (master PC)
Bootstrap the master PC (`pc31`) from a USB installer, using temporary internet access on the first boot.

From the live USB:
```sh
curl -LO https://raw.githubusercontent.com/giovantenne/nixos-lab/master/disko-config.nix
sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./disko-config.nix
sudo nixos-install --flake github:giovantenne/nixos-lab#pc31
reboot
```

After the first reboot, log in and clone the repo:
```sh
git clone https://github.com/giovantenne/nixos-lab.git ~/nixos-config
cd ~/nixos-config
```

Copy the private key (`secret-key`) for the local binary cache into place (e.g., `~/nixos-config/secret-key`).

## 2. Prepare the controller (pc31)
First, update the master IP in `flake.nix` (`labSettings.masterIp`) with the actual IP assigned to `pc31`.

Then build the netboot artifacts:

```sh
nix build .#nixosConfigurations.netboot.config.system.build.netbootRamdisk
```

## 3. Network install (PXE/Netboot)
Start the local services:

```sh
sudo nix run nixpkgs#pixiecore -- --bzImage ./result/bzImage --initrd ./result/initrd --dhcp-no-bind
nix run nixpkgs#harmonia -- --address 0.0.0.0 --port 8080
```

On the netboot RAMDisk, run:

```sh
cd /installer/repo
./setup.sh XX
```

Where `XX` is the PC number (e.g., `./setup.sh 5` for `pc05`).

## 4. Partitioning (Disko)
Declarative config is in `disko-config.nix` with Btrfs subvolumes:

```text
@root    -> /
@nix     -> /nix
@persist -> /persist
```

Target disk: `/dev/sda` with Btrfs label `nixos`.

## 5. Impermanence and persistence
Root is rolled back on every boot (Btrfs rollback). Only these paths persist:

```text
/persist/etc/nixos
/persist/etc/ssh
/persist/home/informatica/.config/Code
```

## 6. Post-install management (Colmena)
The master (`pc31`) acts as the control node and pushes updates via SSH:

```sh
colmena apply --on @lab
```
