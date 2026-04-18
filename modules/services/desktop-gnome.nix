{ inputs, lib, pkgs, ... }:
let
  gv = lib.gvariant;
  telegramDesktop = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.telegram-desktop;
  zedEditor = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.zed-editor;
  zenBrowser = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta;
  batteryConservationPath = "/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode";
  batteryConservationRootToggle = pkgs.writeShellScriptBin "mainframe-battery-conservation-root-toggle" ''
    set -euo pipefail

    mode_path=${lib.escapeShellArg batteryConservationPath}

    if [ ! -e "$mode_path" ]; then
      echo "Battery conservation control is missing: $mode_path" >&2
      exit 1
    fi

    current=$(cat "$mode_path")
    case "$current" in
      0)
        next=1
        message="Battery conservation enabled"
        ;;
      1)
        next=0
        message="Battery conservation disabled"
        ;;
      *)
        echo "Unexpected battery conservation value: $current" >&2
        exit 1
        ;;
    esac

    printf '%s\n' "$next" > "$mode_path"
    printf '%s\n' "$message"
  '';
  batteryConservationToggle = pkgs.writeShellScriptBin "battery-conservation-toggle" ''
    set -euo pipefail

    message=$(/run/wrappers/bin/sudo /run/current-system/sw/bin/mainframe-battery-conservation-root-toggle)
    printf '%s\n' "$message"

    if command -v notify-send >/dev/null 2>&1; then
      notify-send "Battery conservation" "$message"
    fi
  '';
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

  # Lid-close suspend has produced GPU resume failures on this hybrid graphics
  # laptop. Treat the lid like a display cover; use the power key for explicit
  # suspend instead.
  services.logind.settings.Login = {
    HandlePowerKey = "suspend";
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HoldoffTimeoutSec = 2;
    IdleAction = "ignore";
  };

  # logind exposes the lid policy as constant D-Bus properties, so reload it
  # when NixOS switches this configuration.
  systemd.services.systemd-logind.reloadIfChanged = true;

  environment.systemPackages = with pkgs; [
    anki-bin
    audacity
    batteryConservationRootToggle
    batteryConservationToggle
    lidInhibitExtension
    libnotify
    gnomeExtensions.paperwm
    mpv
    nil
    orca-slicer
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
        "/org/gnome/desktop/input-sources/sources"
        "/org/gnome/desktop/wm/preferences/focus-mode"
        "/org/gnome/settings-daemon/plugins/color/night-light-enabled"
        "/org/gnome/settings-daemon/plugins/color/night-light-schedule-automatic"
        "/org/gnome/settings-daemon/plugins/color/night-light-schedule-from"
        "/org/gnome/settings-daemon/plugins/color/night-light-schedule-to"
        "/org/gnome/settings-daemon/plugins/color/night-light-temperature"
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
        "org/gnome/desktop/input-sources" = {
          sources = [
            (gv.mkTuple [ "xkb" "us" ])
            (gv.mkTuple [ "xkb" "ro" ])
          ];
        };
        "org/gnome/desktop/wm/keybindings" = {
          close = [ "<Super>q" ];
        };
        "org/gnome/settings-daemon/plugins/media-keys" = {
          custom-keybindings = [
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/battery-conservation/"
          ];
        };
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/battery-conservation" = {
          name = "Toggle battery conservation";
          command = "/run/current-system/sw/bin/battery-conservation-toggle";
          binding = "<Super>b";
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
        "org/gnome/settings-daemon/plugins/color" = {
          night-light-enabled = true;
          night-light-schedule-automatic = false;
          night-light-schedule-from = 19.0;
          night-light-schedule-to = 8.0;
          night-light-temperature = gv.mkUint32 1700;
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

  security.sudo.extraRules = [
    {
      users = [ "iva" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/mainframe-battery-conservation-root-toggle";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  services.xserver.enable = true;
  services.xserver.xkb.layout = "us,ro";
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
}
