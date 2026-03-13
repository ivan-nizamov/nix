{ inputs, lib, pkgs, ... }:
let
  gv = lib.gvariant;
  nightLightTemperatureStep = 1000;
  nightLightTemperatureDefault = 5000;
  nightLightTemperatureMin = 2500;
  nightLightTemperatureMax = 6500;
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

      case "''${1-}" in
        warmer)
          next=$((current - step))
          summary="Night Light warmer"
          ;;
        cooler)
          next=$((current + step))
          summary="Night Light cooler"
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

      dconf write "$basePath/night-light-enabled" true
      dconf write "$basePath/night-light-schedule-automatic" false
      dconf write "$basePath/night-light-schedule-from" 0.0
      dconf write "$basePath/night-light-schedule-to" 24.0
      dconf write "$basePath/night-light-temperature" "uint32 ''${next}"
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

  # Keep the machine reachable with the lid closed; the GNOME extension is only
  # a session-level toggle, while logind decides whether the host suspends.
  services.logind.settings.Login = {
    HandlePowerKey = "suspend";
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HoldoffTimeoutSec = 2;
    IdleAction = "ignore";
  };

  environment.systemPackages = with pkgs; [
    lidInhibitExtension
    gnomeExtensions.space-bar
    nightLightControl
    telegramDesktop
    vial
    zedEditor
    zenBrowser
  ];

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
        "org/gnome/settings-daemon/plugins/color" = {
          night-light-enabled = true;
          night-light-schedule-automatic = false;
          night-light-schedule-from = 0.0;
          night-light-schedule-to = 24.0;
          night-light-temperature = gv.mkUint32 nightLightTemperatureDefault;
        };
        "org/gnome/settings-daemon/plugins/media-keys" = {
          custom-keybindings = [
            nightLightCoolerBindingPath
            nightLightWarmerBindingPath
          ];
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
    wantedBy = [ "default.target" "graphical-session.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=handle-lid-switch --mode=block --who=LidIgnore --why='Ignore lid close' ${pkgs.coreutils}/bin/sleep infinity";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
}
