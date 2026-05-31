{ inputs, lib, pkgs, ... }:
let
  driftwm = inputs.driftwm.packages.x86_64-linux.default;
  telegramDesktop = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.telegram-desktop;
  zedEditor = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.zed-editor;
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
in
{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  services.displayManager.sessionPackages = [ driftwm ];

  environment.systemPackages = with pkgs; [
    anki-bin
    apple-cursor
    audacity
    batteryConservationRootToggle
    batteryConservationToggle
    driftwm
    libnotify
    mpv
    nil
    nixd
    orca-slicer
    telegramDesktop
    vial
    helium
    zedEditor
    fuzzel
    swaylock
    swayidle
    grim
    slurp
    wlr-randr
    xwayland-satellite
    adwaita-fonts
  ];

  environment.etc."zed/keymap.json".text = zedKeymap;
  environment.etc."driftwm/config.toml".source = ./driftwm-config/config.toml;

  environment.variables = {
    XCURSOR_SIZE = "24";
    XCURSOR_THEME = "macOS";
  };

  services.logind.settings.Login = {
    HandlePowerKey = "hibernate";
    HandleLidSwitch = "suspend";
    HandleLidSwitchDocked = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HoldoffTimeoutSec = 2;
    IdleAction = "ignore";
  };

  systemd.services.systemd-logind.reloadIfChanged = true;

  systemd.tmpfiles.rules = [
    "d /home/iva/.config/zed 0755 iva users - -"
    "L+ /home/iva/.config/zed/keymap.json - - - - /etc/zed/keymap.json"
    "d /home/iva/.config/driftwm 0755 iva users - -"
    "L+ /home/iva/.config/driftwm/config.toml - - - - /etc/driftwm/config.toml"
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

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-wlr ];
  };
}
