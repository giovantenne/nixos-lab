# NixOS Lab Deployment (Zero-Internet Workflow)
This repository manages a 31-PC NixOS lab, optimized for network installation (Netboot) with no internet access and a laptop acting as the local controller.

## Architecture
- Controller (Laptop): `PXE/Netboot`, local `binary cache`, `Colmena` orchestration.
- Nodes (Lab PCs): 31 workstations with `Btrfs` + `Impermanence` (root reset on every reboot).
- Networking: installs and updates over `LAN` only, no internet on PCs.

## 1. First setup at school (master PC)
Bootstrap the master PC (`pc31`) from a USB installer, using temporary internet access on the first boot.

From the live USB:
```sh
sudo nixos-install --flake github:giovantenne/nixos-lab#pc31
```

After the first reboot:
```sh
git clone https://github.com/giovantenne/nixos-lab.git ~/nixos-config
cd ~/nixos-config
```

Then copy the private key for the local binary cache into place on the master PC.

## 2. Prepare the controller (Laptop)
Build the netboot artifacts:

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
sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./disko-config.nix
sudo nixos-install --flake .#pcXX --substituter http://10.22.9.31:8080 --no-substitutes
```

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
The laptop acts as the control node and pushes via SSH:

```sh
colmena apply --on @lab
```
