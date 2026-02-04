{ config, pkgs, lib, ... }:

{
  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Rome";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "it_IT.UTF-8";
    LC_IDENTIFICATION = "it_IT.UTF-8";
    LC_MEASUREMENT = "it_IT.UTF-8";
    LC_MONETARY = "it_IT.UTF-8";
    LC_NAME = "it_IT.UTF-8";
    LC_NUMERIC = "it_IT.UTF-8";
    LC_PAPER = "it_IT.UTF-8";
    LC_TELEPHONE = "it_IT.UTF-8";
    LC_TIME = "it_IT.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Disable GNOME Keyring (no password prompts for Chromium, VSCode, etc.)
  services.gnome.gnome-keyring.enable = lib.mkForce false;
  services.desktopManager.gnome.extraGSettingsOverrides = ''
    [org.gnome.desktop.interface]
    enable-animations=true
    font-name='Liberation Sans 11'
    document-font-name='Liberation Sans 11'
    monospace-font-name='JetBrainsMono Nerd Font Mono 12'

    [org.gnome.desktop.wm.preferences]
    button-layout='appmenu:minimize,maximize,close'
    titlebar-font='Liberation Sans Bold 11'

    [org.gnome.shell]
    enabled-extensions=['ding@rastersoft.com', 'dash-to-dock@micxgx.gmail.com']

    [org.gnome.desktop.default-applications.terminal]
    exec='ghostty'
    exec-arg='--'
  '';

  # Enable VirtualBox guest additions.
  virtualisation.virtualbox.guest.enable = true;
  services.xserver.videoDrivers = [ "virtualbox" ];

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "it";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "it2";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Fonts.
  fonts.packages = [
    pkgs.nerd-fonts.jetbrains-mono
    pkgs.liberation_ttf
  ];
  fonts.fontconfig.defaultFonts = {
    monospace = [ "JetBrainsMono Nerd Font" ];
    sansSerif = [ "Liberation Sans" ];
    serif = [ "Liberation Serif" ];
  };

  # Docker.
  virtualisation.docker.enable = true;

  # User directories.
  systemd.user.services.xdg-user-dirs = {
    description = "Create XDG user directories";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.xdg-user-dirs}/bin/xdg-user-dirs-update";
    };
    wantedBy = [ "default.target" ];
  };

  # Ghostty defaults for all users.
  environment.etc."xdg/ghostty/config".text = ''
    font-size = 14
  '';

  environment.etc."chromium/policies/managed/homepage.json".text = ''
    {
      "HomepageLocation": "https://www.itismeucci.edu.it",
      "HomepageIsNewTabPage": false,
      "RestoreOnStartup": 4,
      "RestoreOnStartupURLs": ["https://www.itismeucci.edu.it"]
    }
  '';

  # Neovim.
  programs.neovim.enable = true;
  programs.neovim.defaultEditor = true;

  # Shell tooling and prompt.
  programs.starship.enable = true;
  programs.starship.enableBashIntegration = true;
  programs.bash.shellAliases = {
    ls = "eza --group-directories-first";
    lsa = "eza -a --group-directories-first";
    lt = "eza -T -L 2 --group-directories-first";
    lta = "eza -a -T -L 2 --group-directories-first";
    ff = "fzf";
  };
  programs.bash.interactiveShellInit = ''
    source ${pkgs.fzf}/share/fzf/key-bindings.bash
    source ${pkgs.fzf}/share/fzf/completion.bash
  '';
  programs.zoxide.enable = true;
  programs.zoxide.enableBashIntegration = true;

  environment.etc."xdg/starship.toml".source = ../assets/starship.toml;

  environment.systemPackages = with pkgs; [
    wget
    curl
    bat
    docker-compose
    eza
    fd
    fzf
    ghostty
    git
    vscode
    chromium
    gcc
    htop
    imagemagick
    ghostscript
    tectonic
    mermaid-cli
    lazygit
    unzip
    python3
    python3Packages.pip
    python3Packages.virtualenv
    luarocks
    lua-language-server
    jdk21
    maven
    nodejs_20
    opencode
    php83
    ripgrep
    try
    xdg-user-dirs
    gnomeExtensions.desktop-icons-ng-ding
    gnomeExtensions.dash-to-dock
  ];

  services.openssh.enable = true;

  system.stateVersion = "25.11";

}
