let
  repoRoot = ../..;
  flake = builtins.getFlake (toString repoRoot);
  cachePublicKeyFile = ../../public-key;
  cachePublicKey =
    if builtins.pathExists cachePublicKeyFile then
      builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile cachePublicKeyFile)
    else
      null;
  adminSshKeyFile = ../../id_ed25519.pub;
  adminSshKey =
    if builtins.pathExists adminSshKeyFile then
      builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile adminSshKeyFile)
    else
      null;
  guiInstanceConfigFile = ../../config/instance.json;
  rawConfig =
    if builtins.pathExists guiInstanceConfigFile then
      builtins.fromJSON (builtins.readFile guiInstanceConfigFile)
    else
      import ../../lab-config.nix;
  normalizedConfig = import ../../lib/normalize-config.nix {
    lib = flake.inputs.nixpkgs.lib;
    inherit rawConfig;
    inherit cachePublicKey;
    inherit adminSshKey;
  };
in
import ../../lib/source-config.nix {
  labConfig = normalizedConfig.labConfig;
}
