# Veyon classroom management: service, keys and base configuration.
#
# - veyon-service runs on every PC (accepts connections from Veyon Master)
# - Public key deployed to all PCs for key-file authentication
# - Private key must be placed manually where needed (not managed by Nix)
# - Base config with all 30 lab PCs pre-configured
{ pkgs, ... }:

let
  # Veyon authentication key paths on the deployed system
  publicKeyDir = "/etc/veyon/keys/public/teacher";
  privateKeyDir = "/etc/veyon/keys/private/teacher";

  # Generate the NetworkObjects JSON array with all 30 lab PCs
  pcList = builtins.genList (n:
    let
      num = n + 1;
      padded = if num < 10 then "0${toString num}" else toString num;
    in
    {
      Type = 1;
      Name = "pc${padded}";
      HostAddress = "10.22.9.${toString num}";
      MacAddress = "";
      Uid = "{pc${padded}-0000-0000-0000-000000000000}";
    }
  ) 30;

  # Build the room container (a location object that holds all PCs)
  roomObject = {
    Type = 2;
    Name = "Laboratorio";
    Uid = "{lab-room-0000-0000-0000-000000000000}";
    NetworkObjects = pcList;
  };

  # Veyon configuration (deployed as /etc/xdg/Veyon Solutions/Veyon.conf)
  veyonConf = ''
    [Authentication]
    Method=1

    [AuthenticationKeys]
    PublicKeyBaseDir=${publicKeyDir}
    PrivateKeyBaseDir=${privateKeyDir}

    [Network]
    PrimaryServicePort=11100

    [Service]
    Autostart=true
    Arguments=

    [VncServer]
    Plugin=builtin

    [BuiltinDirectory]
    NetworkObjects=${builtins.toJSON [ roomObject ]}
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

  # Veyon service: manages VNC server instances per user session
  systemd.services.veyon = {
    description = "Veyon Service";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.veyon}/bin/veyon-service";
      Restart = "on-failure";
      RestartSec = 5;
    };
    path = [ pkgs.veyon ];
  };

  # Group for Veyon Master access (private key ownership)
  users.groups.veyon-master = {};

  # Open the Veyon port (VNC protocol)
  networking.firewall.allowedTCPPorts = [ 11100 ];
}
