let
  configPath = builtins.getEnv "LAB_GUI_VALIDATE_CONFIG_PATH";
  _ =
    if configPath == "" then
      throw "LAB_GUI_VALIDATE_CONFIG_PATH must be set"
    else
      null;
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
  rawConfig = builtins.fromJSON (builtins.readFile (builtins.toPath configPath));
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
