{ pkgs, lib, labConfig, ... }:

lib.mkIf labConfig.features.screensaver.enable {
  # Screensaver scripts and ASCII art logo
  environment.etc."lab/screensaver.txt".source = ../../assets/logo.txt;
  environment.etc."lab/cmd-screensaver.sh" = {
    source = ../../scripts/cmd-screensaver.sh;
    mode = "0755";
  };
  environment.etc."lab/launch-screensaver.sh" = {
    source = ../../scripts/launch-screensaver.sh;
    mode = "0755";
  };
  environment.etc."lab/screensaver-monitor.sh" = {
    source = ../../scripts/screensaver-monitor.sh;
    mode = "0755";
  };

  # Screensaver: watch for GNOME idle (screensaver ActiveChanged signal)
  # and launch the TTE screensaver in a fullscreen Ghostty window.
  systemd.user.services.lab-screensaver = {
    description = "Lab TTE screensaver";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "/etc/lab/screensaver-monitor.sh";
      Restart = "on-failure";
      RestartSec = 5;
    };
    path = [ pkgs.bash pkgs.glib pkgs.gnugrep pkgs.procps pkgs.ghostty pkgs.python3Packages.terminaltexteffects pkgs.ncurses pkgs.systemd ];
  };
}
