{ ... }:
let
  btrfsDevice = "/dev/disk/by-label/nixos";
  btrfsOptions = [ "compress=zstd" "noatime" ];
in
{
  boot.supportedFilesystems = [ "btrfs" ];
  boot.initrd.supportedFilesystems = [ "btrfs" ];

  fileSystems."/" = {
    device = btrfsDevice;
    fsType = "btrfs";
    options = [ "subvol=@root" ] ++ btrfsOptions;
  };

  # ESP partition (UEFI only). On BIOS machines the partition does not
  # exist and nofail ensures the boot continues without errors.
  fileSystems."/boot" = {
    device = "/dev/disk/by-partlabel/ESP";
    fsType = "vfat";
    options = [ "umask=0077" "nofail" ];
  };

  fileSystems."/home/informatica" = {
    device = btrfsDevice;
    fsType = "btrfs";
    options = [ "subvol=@home-informatica" ] ++ btrfsOptions;
  };

  fileSystems."/var/lib/home-snapshots" = {
    device = btrfsDevice;
    fsType = "btrfs";
    options = [ "subvol=@snapshots" ] ++ btrfsOptions;
  };
}
