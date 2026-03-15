{ labConfig, ... }:

{
  users.users = builtins.listToAttrs (map (user: {
    name = user.name;
    value = {
      isNormalUser = true;
      description = user.description;
      extraGroups = user.extraGroups;
      hashedPassword = user.passwordHash;
      openssh.authorizedKeys.keys = user.sshKeys;
    };
  }) labConfig.users.extraUsers);
}
