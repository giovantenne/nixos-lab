{ ... }:
{
  # Btrfs support (filesystems are declared by disko)
  boot.supportedFilesystems = [ "btrfs" ];
  boot.initrd.supportedFilesystems = [ "btrfs" ];
}
