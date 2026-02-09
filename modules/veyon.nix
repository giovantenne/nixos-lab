# Veyon classroom management: service, keys and base configuration.
#
# GNOME runs on Wayland (GNOME 49 dropped X11 session support).
# Veyon's built-in x11vnc cannot capture a Wayland compositor, so we use
# the "External VNC Server" plugin that delegates screen capture to
# gnome-remote-desktop (grd).  grd uses PipeWire + the Wayland screen-cast
# API, then exposes the framebuffer over VNC on port 5900.
#
# gnome-remote-desktop is patched in our overlay to allow multiple
# concurrent VNC connections (upstream limits it to one).
#
# - Public key deployed to all PCs for key-file authentication
# - Private key must be placed manually where needed (not managed by Nix)
# - Classroom/PC layout is configured via Veyon Configurator or veyon-cli
{ pkgs, ... }:

let
  # Veyon authentication key base directories.
  # Veyon resolves keys as: BaseDir/<role>/key
  # e.g. /etc/veyon/keys/public  +  teacher/key
  publicKeyBaseDir = "/etc/veyon/keys/public";
  privateKeyBaseDir = "/etc/veyon/keys/private";

  # VNC password used between veyon-service and gnome-remote-desktop.
  # Both sides must agree on this value.  Since this is LAN-only
  # and already protected by Veyon's RSA key authentication, a simple
  # password is sufficient.
  vncPassword = "veyon";

  # The password encrypted with Veyon's hardcoded RSA-OAEP key.
  # Generated with:
  #   echo -n "veyon" | openssl pkeyutl -encrypt -pubin \
  #     -inkey <(openssl rsa -in /tmp/veyon-hardcoded-key.pem -pubout) \
  #     -pkeyopt rsa_padding_mode:oaep -pkeyopt rsa_oaep_md:sha1 | xxd -p | tr -d '\n'
  # The hardcoded key is embedded in libveyon-core.so.
  vncPasswordEncrypted = "1e44d88e4161df4d14706c39da3b14b1dba0df9ca8a6a6463663e5902bfa40a4fadd19072e5c5efd48c860e0acccffff05a684fee37aee1cedf07d90fd865cbc5ead5d44daba27260e91571e5306c2afcaab4741a781a5a030966bdb05afa1e2c1643e3b55c3b7c9024ee8ef945010879a05b252fba12100e1bb6c045e2336b6fbd9dd74cbc786a735b82eeff0b890302ed1e7117521061816b62f716de2d854c112dde6b09aa419a6c975d722c65ce6a1c988f52a7ba56c720c55fa1a6aa727bdca29dacf5196cbc7b9b3aae54cd6be0fbedb31261e44887f0cdcb22aac78c8b5c3a5e6735a3a083a535e15b12f4133131caec58ad068531f765bd01a131fe2f77c136e39d1348e551e273f85c9a04d795ce309de36b081b6b7999319360dc54e24ad48672527660d32de06ec46b2d3bb86654ea48845688b60da54644eb246b6730e75f9d6fe22f936bed036fedede388619cce640c37c15099c1330f112114cc2f21c7abb5db1e4b2229053706420ccdab2112e53f8c5056ee3d8e398c04df369429b9f1abad23c993b35f33e7894822dfc88a0ca531336fc47d4f4d48fc2c063a0e65afa97825f13485027cfa02c66e47daa2c407de5f1c1bc531b45705d17fb8d849cd47e9a24aa87938ac1fcf4e9bb20b351ae7df2440920c6a6f2fe8104759c706cd8ad19456610c515ac80dfb85cfe0517fbaf8ce1fbf300f96a7569";

  # Veyon configuration (deployed as /etc/xdg/Veyon Solutions/Veyon.conf)
  # Uses the External VNC Server plugin pointing to grd on port 5900.
  veyonConf = ''
    [Authentication]
    Method=1

    [AuthenticationKeys]
    PublicKeyBaseDir=${publicKeyBaseDir}
    PrivateKeyBaseDir=${privateKeyBaseDir}

    [BuiltinDirectory]
    NetworkObjects="@@JsonValue(eyJhIjpbeyJOYW1lIjoiTGFib3JhdG9yaW8iLCJUeXBlIjoyLCJVaWQiOiJ7NjkwNjAyODEtN2I0Ni00ZWJmLWE0MDgtNDI5ZmFkODA5N2I3fSJ9LHsiSG9zdEFkZHJlc3MiOiIxMC4yMi45LjEiLCJOYW1lIjoicGMwMSIsIlBhcmVudFVpZCI6Ins2OTA2MDI4MS03YjQ2LTRlYmYtYTQwOC00MjlmYWQ4MDk3Yjd9IiwiVHlwZSI6MywiVWlkIjoiezU0YTU2OGVhLTU0ZDUtNDY3Ni04NzU3LTZjNWQyZThmNjExMn0ifSx7Ikhvc3RBZGRyZXNzIjoiMTAuMjIuOS4yIiwiTmFtZSI6InBjMDIiLCJQYXJlbnRVaWQiOiJ7NjkwNjAyODEtN2I0Ni00ZWJmLWE0MDgtNDI5ZmFkODA5N2I3fSIsIlR5cGUiOjMsIlVpZCI6Ins0NTU1MmI4Yy0wZDM0LTQ2ODctYjEwNC01N2VlMWQwZDQyN2R9In0seyJIb3N0QWRkcmVzcyI6IjEwLjIyLjkuMyIsIk5hbWUiOiJwYzAzIiwiUGFyZW50VWlkIjoiezY5MDYwMjgxLTdiNDYtNGViZi1hNDA4LTQyOWZhZDgwOTdiN30iLCJUeXBlIjozLCJVaWQiOiJ7MDVlMzAwYjMtODg3Ny00ZGNhLTkxNjMtNmJlZjc3YTU4MTkyfSJ9LHsiSG9zdEFkZHJlc3MiOiIxMC4yMi45LjQiLCJOYW1lIjoicGMwNCIsIlBhcmVudFVpZCI6Ins2OTA2MDI4MS03YjQ2LTRlYmYtYTQwOC00MjlmYWQ4MDk3Yjd9IiwiVHlwZSI6MywiVWlkIjoie2Y3NDMzMTkyLTg5OGYtNGE0Yy04Y2YwLTMyNzYzZjEzYWJhYn0ifSx7Ikhvc3RBZGRyZXNzIjoiMTAuMjIuOS41IiwiTmFtZSI6InBjMDUiLCJQYXJlbnRVaWQiOiJ7NjkwNjAyODEtN2I0Ni00ZWJmLWE0MDgtNDI5ZmFkODA5N2I3fSIsIlR5cGUiOjMsIlVpZCI6IntiMGI0ODFhZi02NzIwLTQ4ZDQtOWY2Yi04Y2ZmMDEzZWE5ZTB9In0seyJIb3N0QWRkcmVzcyI6IjEwLjIyLjkuNiIsIk5hbWUiOiJwYzA2IiwiUGFyZW50VWlkIjoiezY5MDYwMjgxLTdiNDYtNGViZi1hNDA4LTQyOWZhZDgwOTdiN30iLCJUeXBlIjozLCJVaWQiOiJ7ZDNjMGQ3NzktNzYxYy00YTkwLWI3ZmYtZTE2N2Y3NDcxZjJkfSJ9LHsiSG9zdEFkZHJlc3MiOiIxMC4yMi45LjciLCJOYW1lIjoicGMwNyIsIlBhcmVudFVpZCI6Ins2OTA2MDI4MS03YjQ2LTRlYmYtYTQwOC00MjlmYWQ4MDk3Yjd9IiwiVHlwZSI6MywiVWlkIjoiezBlNzUxZDgxLTVlMjctNDhjNy1iYzY2LWFkMGVlMGE5NzRjZn0ifSx7Ikhvc3RBZGRyZXNzIjoiMTAuMjIuOS44IiwiTmFtZSI6InBjMDgiLCJQYXJlbnRVaWQiOiJ7NjkwNjAyODEtN2I0Ni00ZWJmLWE0MDgtNDI5ZmFkODA5N2I3fSIsIlR5cGUiOjMsIlVpZCI6InsxYTZjOTYyYy05ODJmLTQwYTktYTY5YS0yNzI3YzQ0MTYxYzN9In0seyJIb3N0QWRkcmVzcyI6IjEwLjIyLjkuOSIsIk5hbWUiOiJwYzA5IiwiUGFyZW50VWlkIjoiezY5MDYwMjgxLTdiNDYtNGViZi1hNDA4LTQyOWZhZDgwOTdiN30iLCJUeXBlIjozLCJVaWQiOiJ7N2M5NzMwYTctMDBhYi00YzYxLWIzMWItZDg1N2QwNzlhYmVlfSJ9LHsiSG9zdEFkZHJlc3MiOiIxMC4yMi45LjEwIiwiTmFtZSI6InBjMTAiLCJQYXJlbnRVaWQiOiJ7NjkwNjAyODEtN2I0Ni00ZWJmLWE0MDgtNDI5ZmFkODA5N2I3fSIsIlR5cGUiOjMsIlVpZCI6Ins1NGU2MjQwNC0xODAzLTQzZmQtYWQxYS01YmVkODQ3ODQ4NmZ9In0seyJIb3N0QWRkcmVzcyI6IjEwLjIyLjkuMTEiLCJOYW1lIjoicGMxMSIsIlBhcmVudFVpZCI6Ins2OTA2MDI4MS03YjQ2LTRlYmYtYTQwOC00MjlmYWQ4MDk3Yjd9IiwiVHlwZSI6MywiVWlkIjoiezU4ZjU3NmZmLTgxYzMtNDkwYS05MjhkLWY2MzMxN2EyZDEyOX0ifSx7Ikhvc3RBZGRyZXNzIjoiMTAuMjIuOS4xMiIsIk5hbWUiOiJwYzEyIiwiUGFyZW50VWlkIjoiezY5MDYwMjgxLTdiNDYtNGViZi1hNDA4LTQyOWZhZDgwOTdiN30iLCJUeXBlIjozLCJVaWQiOiJ7NzgwNTJiODgtNDI3Yi00ZTc2LTg0ZGUtMzIwYWMyZDFkNGFifSJ9LHsiSG9zdEFkZHJlc3MiOiIxMC4yMi45LjEzIiwiTmFtZSI6InBjMTMiLCJQYXJlbnRVaWQiOiJ7NjkwNjAyODEtN2I0Ni00ZWJmLWE0MDgtNDI5ZmFkODA5N2I3fSIsIlR5cGUiOjMsIlVpZCI6InthMjM2NTM2YS0wZjgzLTQyYjQtYTIzOS04Y2Q5MmUzOWY3MjF9In0seyJIb3N0QWRkcmVzcyI6IjEwLjIyLjkuMTQiLCJOYW1lIjoicGMxNCIsIlBhcmVudFVpZCI6Ins2OTA2MDI4MS03YjQ2LTRlYmYtYTQwOC00MjlmYWQ4MDk3Yjd9IiwiVHlwZSI6MywiVWlkIjoie2QwMDRjY2NlLTBjMjktNDE1Yy1hMDlhLTEzODU1YTkzYjg0NX0ifSx7Ikhvc3RBZGRyZXNzIjoiMTAuMjIuOS4xNSIsIk5hbWUiOiJwYzE1IiwiUGFyZW50VWlkIjoiezY5MDYwMjgxLTdiNDYtNGViZi1hNDA4LTQyOWZhZDgwOTdiN30iLCJUeXBlIjozLCJVaWQiOiJ7MGJmODgzZDAtZWExYi00NWI0LWExZGYtZDBhOGU2ZjQ5YjVifSJ9LHsiSG9zdEFkZHJlc3MiOiIxMC4yMi45LjE2IiwiTmFtZSI6InBjMTYiLCJQYXJlbnRVaWQiOiJ7NjkwNjAyODEtN2I0Ni00ZWJmLWE0MDgtNDI5ZmFkODA5N2I3fSIsIlR5cGUiOjMsIlVpZCI6IntjYWI1NzFjZi1jMmU0LTQ5ZDItYjIxNS1iOTI5ZGQyODRkOTh9In0seyJIb3N0QWRkcmVzcyI6IjEwLjIyLjkuMTciLCJOYW1lIjoicGMxNyIsIlBhcmVudFVpZCI6Ins2OTA2MDI4MS03YjQ2LTRlYmYtYTQwOC00MjlmYWQ4MDk3Yjd9IiwiVHlwZSI6MywiVWlkIjoie2I5NTlkODU5LWZiZTYtNGEzMS04YjZlLTQ4MTFhMWFjMmY1ZX0ifSx7Ikhvc3RBZGRyZXNzIjoiMTAuMjIuOS4xOCIsIk5hbWUiOiJwYzE4IiwiUGFyZW50VWlkIjoiezY5MDYwMjgxLTdiNDYtNGViZi1hNDA4LTQyOWZhZDgwOTdiN30iLCJUeXBlIjozLCJVaWQiOiJ7ZDgyZDIyZTUtMDZiMC00OTNlLWJiMzItOGQ3Mzc1NDg1ZjFhfSJ9LHsiSG9zdEFkZHJlc3MiOiIxMC4yMi45LjE5IiwiTmFtZSI6InBjMTkiLCJQYXJlbnRVaWQiOiJ7NjkwNjAyODEtN2I0Ni00ZWJmLWE0MDgtNDI5ZmFkODA5N2I3fSIsIlR5cGUiOjMsIlVpZCI6Ins4ODgwZGE2ZC01NmU2LTQxMjktOGIzZS05ZGQ0NDBlZmY0YzB9In0seyJIb3N0QWRkcmVzcyI6IjEwLjIyLjkuMjAiLCJOYW1lIjoicGMyMCIsIlBhcmVudFVpZCI6Ins2OTA2MDI4MS03YjQ2LTRlYmYtYTQwOC00MjlmYWQ4MDk3Yjd9IiwiVHlwZSI6MywiVWlkIjoiezlhMDE1MDYzLWI4MzYtNDdhYy1hOWYzLTE4MGEwMDZhMDI0MX0ifSx7Ikhvc3RBZGRyZXNzIjoiMTAuMjIuOS4yMSIsIk5hbWUiOiJwYzIxIiwiUGFyZW50VWlkIjoiezY5MDYwMjgxLTdiNDYtNGViZi1hNDA4LTQyOWZhZDgwOTdiN30iLCJUeXBlIjozLCJVaWQiOiJ7ZGVkMGI4OGMtMTlkNi00OWQzLTg3MTctZDJhNzZkYzg4MTJlfSJ9LHsiSG9zdEFkZHJlc3MiOiIxMC4yMi45LjIyIiwiTmFtZSI6InBjMjIiLCJQYXJlbnRVaWQiOiJ7NjkwNjAyODEtN2I0Ni00ZWJmLWE0MDgtNDI5ZmFkODA5N2I3fSIsIlR5cGUiOjMsIlVpZCI6InsyMWQyNGMyZS0yMzhiLTRjNTQtYWY1NS1jZDU4ZjlkZmQwNmR9In0seyJIb3N0QWRkcmVzcyI6IjEwLjIyLjkuMjMiLCJOYW1lIjoicGMyMyIsIlBhcmVudFVpZCI6Ins2OTA2MDI4MS03YjQ2LTRlYmYtYTQwOC00MjlmYWQ4MDk3Yjd9IiwiVHlwZSI6MywiVWlkIjoiezVkZTlmNGI4LWI5OTQtNGVmZC1iOWIxLTIwYzk0OTgzNTRmOX0ifSx7Ikhvc3RBZGRyZXNzIjoiMTAuMjIuOS4yNCIsIk5hbWUiOiJwYzI0IiwiUGFyZW50VWlkIjoiezY5MDYwMjgxLTdiNDYtNGViZi1hNDA4LTQyOWZhZDgwOTdiN30iLCJUeXBlIjozLCJVaWQiOiJ7ZGFiYzRhYzctNDljNC00MDcyLTliOTQtMzg4YjA3NDMwNGQxfSJ9LHsiSG9zdEFkZHJlc3MiOiIxMC4yMi45LjI1IiwiTmFtZSI6InBjMjUiLCJQYXJlbnRVaWQiOiJ7NjkwNjAyODEtN2I0Ni00ZWJmLWE0MDgtNDI5ZmFkODA5N2I3fSIsIlR5cGUiOjMsIlVpZCI6IntjYjgwZTNjZi1hZDMxLTQ3MjktYjYxNi1lYzYwYzdlMzM0YmV9In0seyJIb3N0QWRkcmVzcyI6IjEwLjIyLjkuMjYiLCJOYW1lIjoicGMyNiIsIlBhcmVudFVpZCI6Ins2OTA2MDI4MS03YjQ2LTRlYmYtYTQwOC00MjlmYWQ4MDk3Yjd9IiwiVHlwZSI6MywiVWlkIjoie2U1OGM3OWE1LTdlYjgtNDhiNS1iZjQ5LWI5ZWY1ZWI2MjU0Mn0ifSx7Ikhvc3RBZGRyZXNzIjoiMTAuMjIuOS4yNyIsIk5hbWUiOiJwYzI3IiwiUGFyZW50VWlkIjoiezY5MDYwMjgxLTdiNDYtNGViZi1hNDA4LTQyOWZhZDgwOTdiN30iLCJUeXBlIjozLCJVaWQiOiJ7Nzc4MzZmYmYtYjc2MS00ZGQ4LTkzNzYtNDYyODEyMjEzN2ZifSJ9LHsiSG9zdEFkZHJlc3MiOiIxMC4yMi45LjI4IiwiTmFtZSI6InBjMjgiLCJQYXJlbnRVaWQiOiJ7NjkwNjAyODEtN2I0Ni00ZWJmLWE0MDgtNDI5ZmFkODA5N2I3fSIsIlR5cGUiOjMsIlVpZCI6IntmYmUyMWYyZS0wODExLTQzYzQtOGUxNi00ZTc3ZTAzOGViMTR9In0seyJIb3N0QWRkcmVzcyI6IjEwLjIyLjkuMjkiLCJOYW1lIjoicGMyOSIsIlBhcmVudFVpZCI6Ins2OTA2MDI4MS03YjQ2LTRlYmYtYTQwOC00MjlmYWQ4MDk3Yjd9IiwiVHlwZSI6MywiVWlkIjoiezY4ZjdiYTI5LTZlYmItNDRlMS04MjFlLThhNTU3NGU0ZDhkMn0ifSx7Ikhvc3RBZGRyZXNzIjoiMTAuMjIuOS4zMCIsIk5hbWUiOiJwYzMwIiwiUGFyZW50VWlkIjoiezY5MDYwMjgxLTdiNDYtNGViZi1hNDA4LTQyOWZhZDgwOTdiN30iLCJUeXBlIjozLCJVaWQiOiJ7NmMxYTMyMTQtODBlMy00MTVmLWE4ZWMtYTk3OTgwM2EzODFifSJ9XX0=)"

    [Network]
    PrimaryServicePort=11100

    [Service]
    Autostart=true
    Arguments=

    [VncServer]
    Plugin={67dfc1c1-8f37-4539-a298-16e74e34fd8b}

    [ExternalVncServer]
    ServerPort=5900
    Password=${vncPasswordEncrypted}
  '';
in
{
  # Install Veyon on all PCs
  environment.systemPackages = [ pkgs.veyon ];

  # Deploy the public key (world-readable) from the repo
  environment.etc."veyon/keys/public/teacher/key" = {
    source = ../veyon-public-key.pem;
    mode = "0644";
  };

  # Deploy Veyon configuration
  environment.etc."xdg/Veyon Solutions/Veyon.conf" = {
    text = veyonConf;
    mode = "0644";
  };

  # Veyon service: runs per user session.
  # On Wayland, veyon-service connects to grd's VNC (port 5900) rather
  # than capturing the screen directly.
  systemd.user.services.veyon-server = {
    description = "Veyon Service";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" "gnome-remote-desktop.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.veyon}/bin/veyon-service";
      Restart = "on-failure";
      RestartSec = 5;
    };
    path = [ pkgs.veyon ];
  };

  # gnome-remote-desktop VNC configuration via dconf.
  # Enable VNC backend, set password authentication, mirror the primary screen.
  services.desktopManager.gnome.extraGSettingsOverrides = ''
    [org.gnome.desktop.remote-desktop.vnc]
    enable=true
    view-only=true
    auth-method='password'
    screen-share-mode='mirror-primary'

    [org.gnome.desktop.remote-desktop.rdp]
    enable=false

    [org.gnome.desktop.remote-desktop.rdp.headless]
    enable=false
  '';

  # Ensure the remote-desktop schemas are visible to gsettings.
  services.desktopManager.gnome.extraGSettingsOverridePackages = [ pkgs.gnome-remote-desktop ];

  # gnome-remote-desktop user service: set the VNC password via environment
  # variable (GNOME Keyring is disabled in common.nix), and ensure it's enabled
  # at session start.
  systemd.user.services.gnome-remote-desktop = {
    wantedBy = [ "gnome-session.target" ];
    serviceConfig.Environment = [
      "GNOME_REMOTE_DESKTOP_TEST_VNC_PASSWORD=${vncPassword}"
    ];
  };

  # Group for Veyon Master access (private key ownership)
  users.groups.veyon-master = {};

  # Open the Veyon and VNC ports.
  # The firewall is disabled in common.nix but we declare the ports
  # explicitly for documentation / defense-in-depth.
  networking.firewall.allowedTCPPorts = [ 11100 5900 ];
}
