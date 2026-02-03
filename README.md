# NixOS flake layout (lab-nixos)

## Hosts
Each host has its own directory under `hosts/`:
- `hosts/pc01/`
- `hosts/pc02/` (template)

### Hardware config
`hardware-configuration.nix` is machine-specific and must be generated on each host:

```sh
sudo nixos-generate-config --show-hardware-config > /etc/nixos/hosts/<host>/hardware-configuration.nix
```

Commit each host’s hardware file (it is required to boot that host).

## Rebuild
Use flakes only:

```sh
sudo nixos-rebuild switch --flake /etc/nixos#pc01
```

## Regenerate pc01 hardware

```sh
sudo nixos-generate-config --show-hardware-config > /etc/nixos/hosts/pc01/hardware-configuration.nix
```
