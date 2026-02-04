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
