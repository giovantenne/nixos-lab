{ pkgs, lib, labConfig, labSettings, ... }:

let
  veyonLocationName = "Lab";
  publicKeyBaseDir = "/etc/veyon/keys/public";
  privateKeyBaseDir = "/etc/veyon/keys/private";
  veyonPublicKeyFile = ../../veyon-public-key.pem;
  hasVeyonPublicKey = builtins.pathExists veyonPublicKeyFile;
  vncPassword = "veyon";
  vncPasswordEncrypted = "1e44d88e4161df4d14706c39da3b14b1dba0df9ca8a6a6463663e5902bfa40a4fadd19072e5c5efd48c860e0acccffff05a684fee37aee1cedf07d90fd865cbc5ead5d44daba27260e91571e5306c2afcaab4741a781a5a030966bdb05afa1e2c1643e3b55c3b7c9024ee8ef945010879a05b252fba12100e1bb6c045e2336b6fbd9dd74cbc786a735b82eeff0b890302ed1e7117521061816b62f716de2d854c112dde6b09aa419a6c975d722c65ce6a1c988f52a7ba56c720c55fa1a6aa727bdca29dacf5196cbc7b9b3aae54cd6be0fbedb31261e44887f0cdcb22aac78c8b5c3a5e6735a3a083a535e15b12f4133131caec58ad068531f765bd01a131fe2f77c136e39d1348e551e273f85c9a04d795ce309de36b081b6b7999319360dc54e24ad48672527660d32de06ec46b2d3bb86654ea48845688b60da54644eb246b6730e75f9d6fe22f936bed036fedede388619cce640c37c15099c1330f112114cc2f21c7abb5db1e4b2229053706420ccdab2112e53f8c5056ee3d8e398c04df369429b9f1abad23c993b35f33e7894822dfc88a0ca531336fc47d4f4d48fc2c063a0e65afa97825f13485027cfa02c66e47daa2c407de5f1c1bc531b45705d17fb8d849cd47e9a24aa87938ac1fcf4e9bb20b351ae7df2440920c6a6f2fe8104759c706cd8ad19456610c515ac80dfb85cfe0517fbaf8ce1fbf300f96a7569";

  padNumber = n: if n < 10 then "0${toString n}" else toString n;

  uuidFromString = value:
    let
      hash = builtins.hashString "sha256" value;
    in
    "{${builtins.substring 0 8 hash}-${builtins.substring 8 4 hash}-${builtins.substring 12 4 hash}-${builtins.substring 16 4 hash}-${builtins.substring 20 12 hash}}";

  locationUid = uuidFromString (builtins.replaceStrings [" "] ["-"] (lib.toLower veyonLocationName));
  hostNumbers = builtins.genList (n: n + 1) labSettings.pcCount;
  networkObjects = {
    a = [
      {
        Name = veyonLocationName;
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

    [VncServer]
    Plugin={67dfc1c1-8f37-4539-a298-16e74e34fd8b}

    [ExternalVncServer]
    ServerPort=5900
    Password=${vncPasswordEncrypted}
  '';
in
lib.mkIf labConfig.features.veyon.enable {
  environment.systemPackages = [
    pkgs.veyon
    (pkgs.makeDesktopItem {
      name = "io.veyon";
      desktopName = "Veyon Master";
      exec = "${pkgs.veyon}/bin/veyon-master";
      icon = "veyon-master";
      comment = "Monitor and control remote computers";
      categories = [ "Qt" "Education" "Network" "RemoteAccess" ];
    })
  ];

  environment.etc."veyon/keys/public/teacher/key" = lib.mkIf hasVeyonPublicKey {
    source = veyonPublicKeyFile;
    mode = "0644";
  };

  environment.etc."xdg/Veyon Solutions/Veyon.conf" = {
    text = veyonConf;
    mode = "0644";
  };

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

  services.desktopManager.gnome.extraGSettingsOverridePackages = [ pkgs.gnome-remote-desktop ];

  systemd.user.services.gnome-remote-desktop = {
    wantedBy = [ "gnome-session.target" ];
    serviceConfig.Environment = [
      "GNOME_REMOTE_DESKTOP_TEST_VNC_PASSWORD=${vncPassword}"
    ];
  };

  networking.firewall.allowedTCPPorts = [ 11100 5900 ];
}
