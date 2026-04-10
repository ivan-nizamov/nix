{ inputs, lib, pkgs, ... }:
let
  gv = lib.gvariant;
  telegramDesktop = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.telegram-desktop;
  zedEditor = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.zed-editor;
  zenBrowser = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta;
  zedKeymap = ''
    [
      {
        "context": "Editor",
        "bindings": {
          "ctrl-shift-v": "editor::Paste"
        }
      }
    ]
  '';
  lidInhibitExtension = pkgs.stdenvNoCC.mkDerivation {
    pname = "gnome-shell-extension-lid-inhibit";
    version = "1";
    src = ./desktop-gnome/lid-inhibit;

    installPhase = ''
      runHook preInstall
      target="$out/share/gnome-shell/extensions/lid-inhibit@localhost"
      mkdir -p "$target"
      cp -r "$src"/. "$target"/
      runHook postInstall
    '';
  };
in
{
  programs.dconf.enable = true;

  # Suspend by default on lid close, even if background processes take generic
  # sleep inhibitors. The GNOME extension still opts into staying awake by
  # taking the dedicated lid-switch inhibitor only when you explicitly enable it.
  services.logind.settings.Login = {
    HandlePowerKey = "suspend";
    HandleLidSwitch = "suspend";
    HandleLidSwitchDocked = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    LidSwitchIgnoreInhibited = true;
    HoldoffTimeoutSec = 2;
    IdleAction = "ignore";
  };

  # Force suspend-to-RAM instead of lighter idle states so a closed lid leaves
  # the machine quiescent until you open it again.
  systemd.sleep.extraConfig = ''
    SuspendState=mem
    MemorySleepMode=deep
  '';

  environment.systemPackages = with pkgs; [
    anki-bin
    audacity
    lidInhibitExtension
    gnomeExtensions.paperwm
    mpv
    nil
    telegramDesktop
    vial
    zedEditor
    zenBrowser
  ];

  environment.etc."zed/keymap.json".text = zedKeymap;

  programs.dconf.profiles.user.databases = [
    {
      locks = [
        "/org/gnome/shell/enabled-extensions"
        "/org/gnome/desktop/wm/preferences/focus-mode"
      ];
      settings = {
        "org/gnome/shell" = {
          enabled-extensions = [
            "paperwm@paperwm.github.com"
            "lid-inhibit@localhost"
          ];
          disable-user-extensions = false;
          disable-extension-version-validation = true;
        };
        "org/gnome/desktop/peripherals/mouse" = {
          accel-profile = "flat";
          natural-scroll = true;
          speed = -0.176;
        };
        "org/gnome/desktop/peripherals/touchpad" = {
          two-finger-scrolling-enabled = true;
        };
        "org/gnome/desktop/background" = {
          color-shading-type = "solid";
          picture-options = "none";
          picture-uri = "";
          picture-uri-dark = "";
          primary-color = "#000000";
          secondary-color = "#000000";
        };
        "org/gnome/desktop/interface" = {
          accent-color = "orange";
          color-scheme = "prefer-dark";
          gtk-theme = "Adwaita-dark";
        };
        "org/gnome/desktop/wm/keybindings" = {
          close = [ "<Super>q" ];
        };
        "org/gnome/desktop/wm/preferences" = {
          focus-mode = "sloppy";
          theme = "Adwaita-dark";
        };
        "org/gnome/settings-daemon/plugins/power" = {
          power-button-action = "nothing";
          sleep-inactive-ac-timeout = gv.mkUint32 0;
          sleep-inactive-ac-type = "nothing";
          sleep-inactive-battery-timeout = gv.mkUint32 0;
          sleep-inactive-battery-type = "nothing";
        };
      };
    }
  ];

  systemd.user.services.lid-inhibit = {
    description = "Ignore lid close (systemd inhibitor)";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=handle-lid-switch --mode=block --who=LidIgnore --why='Ignore lid close' ${pkgs.coreutils}/bin/sleep infinity";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  systemd.tmpfiles.rules = [
    "d /home/iva/.config/zed 0755 iva users - -"
    "L+ /home/iva/.config/zed/keymap.json - - - - /etc/zed/keymap.json"
  ];

  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
}
