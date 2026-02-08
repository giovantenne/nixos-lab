# NixOS Lab Deployment (Zero-Internet Workflow)
This repository manages a 31-PC NixOS lab, optimized for network installation (Netboot) with no internet access and a master PC (`pc31`) acting as the local controller.

## Architecture
- Controller (`pc31`): `PXE/Netboot`, local `binary cache`, `Colmena` orchestration.
- Nodes (Lab PCs): 30 workstations with `Btrfs` filesystem.
- Networking: installs and updates over `LAN` only, no internet on client PCs.

## 1. First setup at school (master PC)
Bootstrap the master PC (`pc31`) from a USB installer, using temporary internet access on the first boot. **BIOS/Legacy boot is required** — disable UEFI in BIOS settings if needed.

From the live USB, partition and install:
```sh
curl -LO https://raw.githubusercontent.com/giovantenne/nixos-lab/master/disko-bios.nix
sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./disko-bios.nix
sudo nixos-install --flake github:giovantenne/nixos-lab#pc31 --no-write-lock-file --no-root-passwd
reboot
```

After the first reboot, log in as `admin` and clone the repo:
```sh
git clone https://github.com/giovantenne/nixos-lab.git ~/nixos-config
cd ~/nixos-config
```

Copy the binary cache private key (`secret-key`) into the repo folder. It is already in `.gitignore`.

Copy the admin SSH private key (`admin_id_ed25519`) to `~/.ssh/id_ed25519`:
```sh
cp admin_id_ed25519 ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
```

## 2. Prepare the controller (pc31)
All commands below run from `~/nixos-config` on `pc31`.

Update `masterIp` and `ifaceName` at the top of `flake.nix`:
```sh
ip -4 addr                  # find the DHCP address
vim flake.nix               # edit masterIp and ifaceName
```

Rebuild pc31 to apply the new settings:
```sh
sudo nixos-rebuild switch --flake .#pc31 --no-write-lock-file
```

Build the netboot artifacts:
```sh
nix build .#nixosConfigurations.netboot.config.system.build.kernel --out-link result-kernel --rebuild
nix build .#nixosConfigurations.netboot.config.system.build.netbootRamdisk --out-link result-initrd --rebuild
nix build .#nixosConfigurations.netboot.config.system.build.netbootIpxeScript --out-link result-ipxe --rebuild
```

Pre-build all client closures so installs work offline via the local cache:
```sh
nix build .#nixosConfigurations.pc{01..30}.config.system.build.toplevel
```

## 3. Network install (PXE/Netboot)
Temporarily remove the static IP so pixiecore sees only the DHCP address (it returns after a reboot):
```sh
iface=$(ip -4 addr | awk '/10.22.9.31/{print $NF; exit}')
sudo ip addr del 10.22.9.31/24 dev "$iface"
```

Start the local services in two separate terminals:
```sh
# Terminal 1: Binary cache
./scripts/run-harmonia.sh

# Terminal 2: PXE server
CMDLINE=$(grep '^kernel ' result-ipxe/netboot.ipxe | sed 's/^kernel [^ ]* //')
sudo nix run nixpkgs#pixiecore -- boot result-kernel/bzImage result-initrd/initrd --cmdline "$CMDLINE"
```

On each client PC, enable PXE/Network boot in BIOS. The PC will boot into a NixOS ramdisk.

On the booted client, run the installer:
```sh
cd /installer/repo
./setup.sh XX
```
Where `XX` is the PC number (e.g., `./setup.sh 5` for `pc05`).

When all clients are installed, restore the static IP on pc31 (or just reboot it):
```sh
iface=$(ip -4 addr | awk '/10.22.9.31/{print $NF; exit}')
sudo ip addr add 10.22.9.31/24 dev "$iface"
```

## 4. Partitioning and Boot (Disko)
Declarative disk config is in `disko-bios.nix`. All machines must boot in **BIOS/Legacy mode**.

GRUB installs to the MBR of `/dev/sda`, which works on any BIOS machine.

Target disk: `/dev/sda` with Btrfs label `nixos` and subvolumes:
- `@root` -> `/`
- `@home-informatica` -> `/home/informatica`
- `@snapshots` -> `/var/lib/home-snapshots`

## 5. Home Reset and Snapshots
The `informatica` home directory resets to a clean template on every boot:

- **Template**: generated at activation time with git config, VS Code settings, and XDG directories
- **Snapshots**: last 5 versions saved in `/var/lib/home-snapshots/` (root only)

To recover student work from a previous session:
```sh
sudo ls /var/lib/home-snapshots/snapshot-1/
sudo cp /var/lib/home-snapshots/snapshot-1/file.txt /home/informatica/
```

## 6. Post-install management (Colmena)
The master (`pc31`) pushes updates to all lab PCs via SSH:

```sh
# Start the binary cache (required for client builds)
./scripts/run-harmonia.sh

# Deploy to all lab PCs
colmena apply --on @lab

# Deploy to a single PC
colmena apply --on pc05
```

## 7. Manual rebuild
To manually rebuild a single PC from the latest GitHub config:
```sh
sudo nixos-rebuild switch --flake github:giovantenne/nixos-lab#pc31 --no-write-lock-file --refresh
```
Replace `pc31` with the appropriate hostname (e.g., `pc01`, `pc15`).

## 8. Veyon (classroom management)
Veyon is packaged locally (not available in nixpkgs) and deployed on all PCs. The `veyon-service` systemd unit runs on every machine, accepting connections on port **11100**.

Authentication uses RSA key-file mode:
- **Public key** (`veyon-public-key.pem`): committed in the repo, deployed to `/etc/veyon/keys/public/teacher/key` on all PCs.
- **Private key** (`veyon-private-key.pem`): in `.gitignore`, must be placed manually on machines where Veyon Master will be used.

### Generating keys
Keys are generated once with openssl:
```sh
openssl genrsa -out veyon-private-key.pem 4096
openssl rsa -in veyon-private-key.pem -pubout -out veyon-public-key.pem
```

### Distributing the private key
Copy the private key to the machines where admin or docente need Veyon Master:
```sh
sudo install -d -m 0750 -g veyon-master /etc/veyon/keys/private/teacher
sudo install -m 0640 -g veyon-master veyon-private-key.pem /etc/veyon/keys/private/teacher/key
```
Only users in the `veyon-master` group (`admin`, `docente`) can read the private key and use Veyon Master.

### Configuration
A base configuration with all 30 lab PCs pre-mapped is deployed to `/etc/xdg/Veyon Solutions/Veyon.conf`. Admin or docente can customize the layout via `veyon-configurator`.
