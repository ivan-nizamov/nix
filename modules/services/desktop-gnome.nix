{ inputs, lib, pkgs, ... }:
let
  gv = lib.gvariant;
  amberGreenLevel = 0.69;
  amberGreenBrightness = amberGreenLevel / 2.0 - 0.5;
  amberGreenContrast = amberGreenLevel - 1.0;
  amberToggleBindingPath = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/amber-screen-toggle/";
  amberResetBindingPath = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/amber-screen-reset/";
  nightLightTemperatureStep = 1000;
  nightLightTemperatureDefault = 5000;
  nightLightTemperatureMin = 1000;
  nightLightTemperatureMax = 10000;
  amberScreenMode = pkgs.writeShellApplication {
    name = "amber-screen-mode";
    runtimeInputs = [
      pkgs.dconf
    ];
    text = ''
      set -eu

      appsPath="/org/gnome/desktop/a11y/applications"
      magnifierPath="/org/gnome/desktop/a11y/magnifier"

      write_on() {
        dconf write "$appsPath/screen-magnifier-enabled" true
        dconf write "$magnifierPath/screen-position" "'full-screen'"
        dconf write "$magnifierPath/lens-mode" false
        dconf write "$magnifierPath/mag-factor" 1.0
        dconf write "$magnifierPath/invert-lightness" false
        dconf write "$magnifierPath/color-saturation" 0.0
        dconf write "$magnifierPath/brightness-red" 0.0
        dconf write "$magnifierPath/contrast-red" 0.0
        dconf write "$magnifierPath/brightness-green" ${toString amberGreenBrightness}
        dconf write "$magnifierPath/contrast-green" ${toString amberGreenContrast}
        dconf write "$magnifierPath/brightness-blue" -0.5
        dconf write "$magnifierPath/contrast-blue" -1.0
        dconf write "$magnifierPath/show-cross-hairs" false
      }

      write_off() {
        dconf write "$magnifierPath/brightness-red" 0.0
        dconf write "$magnifierPath/brightness-green" 0.0
        dconf write "$magnifierPath/brightness-blue" 0.0
        dconf write "$magnifierPath/contrast-red" 0.0
        dconf write "$magnifierPath/contrast-green" 0.0
        dconf write "$magnifierPath/contrast-blue" 0.0
        dconf write "$magnifierPath/color-saturation" 1.0
        dconf write "$magnifierPath/invert-lightness" false
        dconf write "$magnifierPath/mag-factor" 1.0
        dconf write "$appsPath/screen-magnifier-enabled" false
      }

      is_on() {
        [ "$(dconf read "$appsPath/screen-magnifier-enabled" 2>/dev/null || echo false)" = "true" ]
      }

      case "''${1-on}" in
        on)
          write_on
          ;;
        off)
          write_off
          ;;
        toggle)
          if is_on; then
            write_off
          else
            write_on
          fi
          ;;
        status)
          if is_on; then
            echo on
          else
            echo off
          fi
          ;;
        *)
          echo "usage: amber-screen-mode {on|off|toggle|status}" >&2
          exit 1
          ;;
      esac
    '';
  };
  nightLightControl = pkgs.writeShellApplication {
    name = "night-light-control";
    runtimeInputs = [
      pkgs.dconf
    ];
    text = ''
      set -eu

      basePath="/org/gnome/settings-daemon/plugins/color"
      step=${toString nightLightTemperatureStep}
      min=${toString nightLightTemperatureMin}
      max=${toString nightLightTemperatureMax}

      current=$(dconf read "$basePath/night-light-temperature" | awk '{ print $2 }')
      enabled=$(dconf read "$basePath/night-light-enabled")
      automatic=$(dconf read "$basePath/night-light-schedule-automatic")
      scheduleFrom=$(dconf read "$basePath/night-light-schedule-from")
      scheduleTo=$(dconf read "$basePath/night-light-schedule-to")
      changed=0

      case "''${1-}" in
        warmer)
          next=$((current - step))
          ;;
        cooler)
          next=$((current + step))
          ;;
        *)
          echo "usage: night-light-control {warmer|cooler}" >&2
          exit 1
          ;;
      esac

      if [ "$next" -lt "$min" ]; then
        next=$min
      fi

      if [ "$next" -gt "$max" ]; then
        next=$max
      fi

      if [ "$enabled" != "true" ]; then
        dconf write "$basePath/night-light-enabled" true
        changed=1
      fi

      if [ "$automatic" != "false" ]; then
        dconf write "$basePath/night-light-schedule-automatic" false
        changed=1
      fi

      if [ "$scheduleFrom" != "0.0" ]; then
        dconf write "$basePath/night-light-schedule-from" 0.0
        changed=1
      fi

      if [ "$scheduleTo" != "24.0" ]; then
        dconf write "$basePath/night-light-schedule-to" 24.0
        changed=1
      fi

      if [ "$next" != "$current" ]; then
        dconf write "$basePath/night-light-temperature" "uint32 ''${next}"
        changed=1
      fi

      if [ "$changed" -eq 0 ]; then
        exit 0
      fi
    '';
  };
  nightLightCoolerBindingPath = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/night-light-cooler/";
  nightLightWarmerBindingPath = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/night-light-warmer/";
  spaceBarStyles = ''
    .space-bar {
      -natural-hpadding: 12px;
    }

    .space-bar-workspace-label.active {
      margin: 0 4px;
      background-color: rgba(255,255,255,0.3);
      color: rgba(255,255,255,1);
      border-color: rgba(0,0,0,0);
      font-weight: 700;
      border-radius: 4px;
      border-width: 0px;
      padding: 3px 8px;
    }

    .space-bar-workspace-label.inactive {
      margin: 0 4px;
      background-color: rgba(0,0,0,0);
      color: rgba(255,255,255,1);
      border-color: rgba(0,0,0,0);
      font-weight: 700;
      border-radius: 4px;
      border-width: 0px;
      padding: 3px 8px;
    }

    .space-bar-workspace-label.inactive.empty {
      margin: 0 4px;
      background-color: rgba(0,0,0,0);
      color: rgba(255,255,255,0.5);
      border-color: rgba(0,0,0,0);
      font-weight: 700;
      border-radius: 4px;
      border-width: 0px;
      padding: 3px 8px;
    }
  '';
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
    amberScreenMode
    lidInhibitExtension
    gnomeExtensions.space-bar
    nightLightControl
    telegramDesktop
    vial
    zedEditor
    zenBrowser
  ];

  environment.etc."zed/keymap.json".text = zedKeymap;

  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/shell" = {
          enabled-extensions = [
            "space-bar@luchrioh"
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
        "org/gnome/desktop/a11y/applications" = {
          screen-magnifier-enabled = true;
        };
        "org/gnome/desktop/a11y/magnifier" = {
          lens-mode = false;
          mag-factor = 1.0;
          screen-position = "full-screen";
          invert-lightness = false;
          color-saturation = 0.0;
          brightness-red = 0.0;
          contrast-red = 0.0;
          brightness-green = amberGreenBrightness;
          contrast-green = amberGreenContrast;
          brightness-blue = -0.5;
          contrast-blue = -1.0;
          show-cross-hairs = false;
        };
        "org/gnome/settings-daemon/plugins/color" = {
          night-light-enabled = true;
          night-light-schedule-automatic = false;
          night-light-schedule-from = 0.0;
          night-light-schedule-to = 24.0;
          night-light-temperature = gv.mkUint32 nightLightTemperatureDefault;
        };
        "org/gnome/settings-daemon/plugins/media-keys" = {
          custom-keybindings = [
            amberToggleBindingPath
            amberResetBindingPath
            nightLightCoolerBindingPath
            nightLightWarmerBindingPath
          ];
        };
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/amber-screen-toggle" = {
          binding = "<Super>backslash";
          command = "${amberScreenMode}/bin/amber-screen-mode toggle";
          name = "Amber Screen Toggle";
        };
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/amber-screen-reset" = {
          binding = "<Shift><Super>backslash";
          command = "${amberScreenMode}/bin/amber-screen-mode off";
          name = "Amber Screen Reset";
        };
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/night-light-cooler" = {
          binding = "<Super>bracketleft";
          command = "${nightLightControl}/bin/night-light-control cooler";
          name = "Night Light Cooler";
        };
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/night-light-warmer" = {
          binding = "<Super>bracketright";
          command = "${nightLightControl}/bin/night-light-control warmer";
          name = "Night Light Warmer";
        };
        "org/gnome/desktop/wm/keybindings" = {
          close = [ "<Super>q" ];
        };
        "org/gnome/settings-daemon/plugins/power" = {
          power-button-action = "nothing";
          sleep-inactive-ac-timeout = gv.mkUint32 0;
          sleep-inactive-ac-type = "nothing";
          sleep-inactive-battery-timeout = gv.mkUint32 0;
          sleep-inactive-battery-type = "nothing";
        };
        "org/gnome/shell/extensions/space-bar/appearance" = {
          application-styles = spaceBarStyles;
          active-workspace-font-weight = "700";
          inactive-workspace-font-weight = "700";
          empty-workspace-font-weight = "700";
        };
        "org/gnome/shell/extensions/space-bar/behavior" = {
          always-show-numbers = false;
          smart-workspace-names = false;
          indicator-style = "workspaces-bar";
          position = "left";
          scroll-wheel = "panel";
          toggle-overview = false;
        };
        "org/gnome/shell/extensions/space-bar/shortcuts" = {
          enable-move-to-workspace-shortcuts = true;
          enable-activate-workspace-shortcuts = true;
          activate-empty-key = [ "<Super>j" ];
          back-and-forth = false;
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

  systemd.user.services.amber-monochrome = {
    description = "Apply amber monochrome display filter";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${amberScreenMode}/bin/amber-screen-mode on";
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
