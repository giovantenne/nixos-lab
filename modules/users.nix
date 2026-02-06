{ ... }:

{
  # Passwords are managed declaratively, cannot be changed manually
  users.mutableUsers = false;

  # Disable root login
  users.users.root.hashedPassword = "!";

  users.users.admin = {
    isNormalUser = true;
    description = "admin";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    hashedPassword = "$6$ARnkNr/aUtpwcxD4$kogxkOwkeqvwtsd0WXyQ3IhqXdLQgSXyjHV3Jb2GtPpHQWm/epABQvMTKmAu9MoVeLO5NTQCsjYwmadyumDas.";
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

  users.users.docente = {
    isNormalUser = true;
    description = "docente";
    extraGroups = [ "networkmanager" "docker" ];
    hashedPassword = "$6$6g9aF3VchadHSTHG$wry4cmIljUGHB4SamaWB7ZeTtjbrBmRpP323AX5Jw3xMkRn4N.is6cH3J/0XgE8Xk01FhzwMLtA4KISsVMAbK.";
  };

  services.displayManager.autoLogin = {
    enable = true;
    user = "informatica";
  };
}
