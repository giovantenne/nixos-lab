# Veyon classroom management: service, keys and base configuration.
#
# GNOME runs on X11 (Wayland is disabled in common.nix via
# services.displayManager.gdm.wayland = false).  Veyon uses its
# built-in x11vnc for screen capture — no external VNC server needed.
#
# - Public key deployed to all PCs for key-file authentication
# - Private key must be placed manually where needed (not managed by Nix)
# - Classroom/PC layout is configured via Veyon Configurator or veyon-cli
{ pkgs, lib, labSettings, ... }:

let
  # Veyon authentication key base directories.
  # Veyon resolves keys as: BaseDir/<role>/key
  # e.g. /etc/veyon/keys/public  +  teacher/key
  publicKeyBaseDir = "/etc/veyon/keys/public";
  privateKeyBaseDir = "/etc/veyon/keys/private";

  padNumber = n: if n < 10 then "0${toString n}" else toString n;

  uuidFromString = value:
    let
      hash = builtins.hashString "sha256" value;
    in
    "{${builtins.substring 0 8 hash}-${builtins.substring 8 4 hash}-${builtins.substring 12 4 hash}-${builtins.substring 16 4 hash}-${builtins.substring 20 12 hash}}";

  locationUid = uuidFromString "laboratorio";

  hostNumbers = builtins.genList (n: n + 1) labSettings.pcCount;

  networkObjects = {
    a = [
      {
        Name = "Laboratorio";
        Type = 2;
        Uid = locationUid;
      }
    ] ++ map (n: {
      HostAddress = "${labSettings.networkBase}.${toString n}";
      Name = "pc${padNumber n}";
      ParentUid = locationUid;
      Type = 3;
      Uid = uuidFromString "pc${padNumber n}";
    }) hostNumbers;
  };

  networkObjectsJson = builtins.toJSON networkObjects;

  networkObjectsBase64 = builtins.readFile (pkgs.runCommand "veyon-network-objects" {} ''
    printf '%s' ${lib.escapeShellArg networkObjectsJson} | ${pkgs.coreutils}/bin/base64 -w0 > $out
  '');

  # Veyon configuration (deployed as /etc/xdg/Veyon Solutions/Veyon.conf)
  # Uses the built-in VNC server (x11vnc) for X11 screen capture.
  veyonConf = ''
    [Authentication]
    Method=1

    [AuthenticationKeys]
    PublicKeyBaseDir=${publicKeyBaseDir}
    PrivateKeyBaseDir=${privateKeyBaseDir}

    [BuiltinDirectory]
    NetworkObjects="@@JsonValue(${networkObjectsBase64})"

    [Network]
    PrimaryServicePort=11100

    [Service]
    Autostart=true
    Arguments=
    HideTrayIcon=true

    [Master]
    RemoteAccessImageQuality=0
    ComputerMonitoringImageQuality=2
    ComputerMonitoringUpdateInterval=1000
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
  # On X11, veyon-service uses its built-in x11vnc to capture the screen.
  systemd.user.services.veyon-server = {
    description = "Veyon Service";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.veyon}/bin/veyon-service";
      Restart = "on-failure";
      RestartSec = 5;
    };
    path = [ pkgs.veyon ];
  };

  # Group for Veyon Master access (private key ownership)
  users.groups.veyon-master = {};

  # Open the Veyon port.
  # The firewall is disabled in common.nix but we declare the port
  # explicitly for documentation / defense-in-depth.
  networking.firewall.allowedTCPPorts = [ 11100 ];
}
