{ lib, ... }:
let
  btrfsDevice = "/dev/disk/by-label/nixos";
in
{
  boot.supportedFilesystems = [ "btrfs" ];
  boot.initrd.supportedFilesystems = [ "btrfs" ];

  # Define fileSystems manually (same for BIOS and UEFI, only /boot differs)
  fileSystems."/" = {
    device = btrfsDevice;
    fsType = "btrfs";
    options = [ "subvol=@root" "compress=zstd" "noatime" ];
  };

  fileSystems."/nix" = {
    device = btrfsDevice;
    fsType = "btrfs";
    options = [ "subvol=@nix" "compress=zstd" "noatime" ];
  };

  fileSystems."/persist" = {
    device = btrfsDevice;
    fsType = "btrfs";
    options = [ "subvol=@persist" "compress=zstd" "noatime" ];
    neededForBoot = true;
  };

  boot.initrd.postDeviceCommands = lib.mkAfter ''
    mkdir -p /mnt
    mount -o subvol=/ ${btrfsDevice} /mnt
    if [ -d /mnt/@root-blank ]; then
      if [ -d /mnt/@root ]; then
        btrfs subvolume delete /mnt/@root
      fi
      btrfs subvolume snapshot /mnt/@root-blank /mnt/@root
    fi
    umount /mnt
  '';

  systemd.services.create-root-blank = {
    description = "Create Btrfs clean root snapshot";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      if [ ! -e /persist/.root-blank-created ]; then
        mkdir -p /mnt
        mount -o subvol=/ ${btrfsDevice} /mnt
        if [ ! -d /mnt/@root-blank ]; then
          btrfs subvolume snapshot /mnt/@root /mnt/@root-blank
        fi
        umount /mnt
        touch /persist/.root-blank-created
      fi
    '';
  };

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/etc/nixos"
      {
        directory = "/home/informatica";
        user = "informatica";
        group = "users";
        mode = "0755";
      }
    ];
    files = [
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };
}
