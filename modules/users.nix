{ ... }:

{
  users.users.admin = {
    isNormalUser = true;
    description = "admin";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHZn4yG1+sFGHU8hMnvH5N+HHsGhDpXcgrHUDldvs9+a admin@pc01"
    ];
  };

  users.users.informatica = {
    isNormalUser = true;
    description = "informatica";
    extraGroups = [ "networkmanager" ];
    hashedPassword = "$6$d7Y6egRmcsYHzkJE$sODDV60wD7qra8HAKgzAIOk2/EMMTqpb7LW2rbkvp/FNu9muJZeQT0FIbipUesftWrnGPlszKyKGmNtVdEbVs1";
  };

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "informatica";
}
