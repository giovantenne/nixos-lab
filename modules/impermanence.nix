{ lib, ... }:
let
  btrfsDevice = "/dev/disk/by-label/nixos";
in
{
  boot.supportedFilesystems = [ "btrfs" ];
  boot.initrd.supportedFilesystems = [ "btrfs" ];

  # Mark /persist as neededForBoot for impermanence
  fileSystems."/persist".neededForBoot = true;

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
      "/etc/ssh"
      "/home/informatica/.config/Code"
    ];
  };
}
