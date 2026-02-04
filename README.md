# NixOS Lab Deployment (Zero-Internet Workflow)
This repository manages a 31-PC NixOS lab, optimized for network installation (Netboot) with no internet access and a master PC (`pc31`) acting as the local controller.

## Architecture
- Controller (`pc31`): `PXE/Netboot`, local `binary cache`, `Colmena` orchestration.
- Nodes (Lab PCs): 30 workstations with `Btrfs` filesystem.
- Networking: installs and updates over `LAN` only, no internet on client PCs.

## 1. First setup at school (master PC)
Bootstrap the master PC (`pc31`) from a USB installer, using temporary internet access on the first boot.

From the live USB, detect boot mode and partition accordingly:
```sh
if [ -d /sys/firmware/efi ]; then
  curl -LO https://raw.githubusercontent.com/giovantenne/nixos-lab/master/disko-uefi.nix
  sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./disko-uefi.nix
else
  curl -LO https://raw.githubusercontent.com/giovantenne/nixos-lab/master/disko-bios.nix
  sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./disko-bios.nix
fi
sudo nixos-install --flake github:giovantenne/nixos-lab#pc31 --no-write-lock-file --no-root-passwd
reboot
```

After the first reboot, log in and clone the repo:
```sh
git clone https://github.com/giovantenne/nixos-lab.git ~/nixos-config
cd ~/nixos-config
```

Copy the private key (`secret-key`) for the local binary cache into the repo folder (`~/nixos-config/secret-key`). It is already in `.gitignore`.

## 2. Prepare the controller (pc31)
First, update the master IP in `flake.nix` (`labSettings.masterIp`) with the actual IP assigned to `pc31`.

After changing the IP, run a local rebuild on `pc31` to update Nix settings:

```sh
sudo nixos-rebuild switch --flake .#pc31 --no-write-lock-file --refresh
```

Then build the netboot artifacts (no sudo needed):

```sh
nix build .#nixosConfigurations.netboot.config.system.build.netbootRamdisk
```

## 3. Network install (PXE/Netboot)
Start the local services in two separate terminals:

```sh
# Terminal 1: PXE server
sudo nix run nixpkgs#pixiecore -- boot ./result/bzImage ./result/initrd --dhcp-no-bind

# Terminal 2: Binary cache (defaults to port 5000)
nix run nixpkgs#harmonia -- --secret-key-file ./secret-key

# If harmonia flags differ on your version, run:
# nix run nixpkgs#harmonia -- --help
```

On the netboot RAMDisk, run:

```sh
cd /installer/repo
./setup.sh XX
```

Where `XX` is the PC number (e.g., `./setup.sh 5` for `pc05`).

## 4. Partitioning (Disko)
Declarative configs are in `disko-bios.nix` and `disko-uefi.nix`. The script auto-detects boot mode.

Target disk: `/dev/sda` with Btrfs label `nixos` and subvolumes:
- `@root` -> `/`
- `@home-informatica` -> `/home/informatica`
- `@snapshots` -> `/var/lib/home-snapshots`

## 5. Home Reset and Snapshots
The `informatica` home directory resets to a clean template on every boot:

- **Template**: generated at build time with VS Code extensions and git config
- **Snapshots**: last 5 versions saved in `/var/lib/home-snapshots/` (root only)

To recover student work from a previous session:
```sh
sudo ls /var/lib/home-snapshots/snapshot-1/
sudo cp /var/lib/home-snapshots/snapshot-1/file.txt /home/informatica/
```

To add VS Code extensions, edit `modules/home-reset.nix`:
```nix
vscodeExtensions = [
  "vscjava.vscode-java-pack"
  "ritwickdey.liveserver"
  "ms-python.python"  # add new extensions here
];
```

## 6. Post-install management (Colmena)
The master (`pc31`) acts as the control node and pushes updates via SSH:

```sh
colmena apply --on @lab
```

## 7. Manual rebuild
To manually rebuild a single PC from the latest GitHub config:

```sh
sudo nixos-rebuild switch --flake github:giovantenne/nixos-lab#pc31 --no-write-lock-file --refresh
```

Replace `pc31` with the appropriate hostname (e.g., `pc01`, `pc15`).
