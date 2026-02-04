{ pkgs, lib, ... }:

let
  # Shared settings - also used by home-reset.nix for informatica template
  vscodeSettings = builtins.fromJSON (builtins.readFile ../assets/vscode-settings.json);
in
{
  programs.vscode = {
    enable = true;
    profiles.default.userSettings = vscodeSettings;
  };

  programs.bash.enable = true;

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
  };

  xdg.configFile."starship.toml".source = ../assets/starship.toml;

  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications = {
    "text/html" = "chromium-browser.desktop";
    "x-scheme-handler/http" = "chromium-browser.desktop";
    "x-scheme-handler/https" = "chromium-browser.desktop";
  };

  dconf.settings."org/gnome/shell".favorite-apps = [
    "com.mitchellh.ghostty.desktop"
    "chromium-browser.desktop"
    "code.desktop"
    "org.gnome.Nautilus.desktop"
    "org.gnome.Calculator.desktop"
    "org.gnome.TextEditor.desktop"
  ];
}
