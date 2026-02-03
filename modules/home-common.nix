{ pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    profiles.default.userSettings = {
      "update.mode" = "none";
      "update.enableWindowsBackgroundUpdates" = false;
      "update.showReleaseNotes" = false;
      "extensions.autoCheckUpdates" = false;
      "extensions.autoUpdate" = false;
      "java.jdt.ls.java.home" = "/run/current-system/sw/lib/openjdk";
    };
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
