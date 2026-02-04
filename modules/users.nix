{ ... }:

{
  users.users.admin = {
    isNormalUser = true;
    description = "admin";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAeU4p5Nv6Ak8AJp4GiTlWHJUzuOEOuv5C2Am5mRnffV admin@pc31"
    ];
  };

  users.users.informatica = {
    isNormalUser = true;
    description = "informatica";
    extraGroups = [ "networkmanager" "docker" ];
    hashedPassword = "$6$d7Y6egRmcsYHzkJE$sODDV60wD7qra8HAKgzAIOk2/EMMTqpb7LW2rbkvp/FNu9muJZeQT0FIbipUesftWrnGPlszKyKGmNtVdEbVs1";
  };

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "informatica";
}
