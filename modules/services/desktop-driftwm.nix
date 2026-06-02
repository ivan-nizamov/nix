{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  driftwmPackage = inputs.driftwm.packages.${pkgs.stdenv.hostPlatform.system}.default;
  heliumPackage = pkgs.helium;
  driftwm = pkgs.symlinkJoin {
    name = "${driftwmPackage.name}-nixos-session";
    paths = [ driftwmPackage ];
    passthru.providedSessions = [ "driftwm" ];
    postBuild = ''
      service_file="$out/share/systemd/user/driftwm.service"
      desktop_file="$out/share/wayland-sessions/driftwm.desktop"

      rm "$service_file" "$desktop_file"
      install -Dm0644 ${driftwmPackage}/share/systemd/user/driftwm.service "$service_file"
      install -Dm0644 ${driftwmPackage}/share/wayland-sessions/driftwm.desktop "$desktop_file"

      substituteInPlace "$service_file" \
        --replace-fail 'ExecStart=driftwm' "ExecStart=$out/bin/driftwm"
      substituteInPlace "$desktop_file" \
        --replace-fail 'Exec=driftwm-session' "Exec=$out/bin/driftwm-session"
    '';
  };
  heliumLauncher = pkgs.writeShellScriptBin "helium" ''
    set -euo pipefail

    profile_dir="$HOME/.config/net.imput.helium"
    if ! pgrep -x helium >/dev/null 2>&1; then
      rm -f "$profile_dir/SingletonLock" "$profile_dir/SingletonSocket" "$profile_dir/SingletonCookie"
    fi

    exec ${lib.getExe heliumPackage} "$@"
  '';
  telegramDesktopUnwrapped = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.telegram-desktop;
  telegramDesktop = pkgs.symlinkJoin {
    name = "${telegramDesktopUnwrapped.name}-xwayland";
    paths = [ telegramDesktopUnwrapped ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/Telegram" \
        --set QT_QPA_PLATFORM xcb

      desktop_file="$out/share/applications/org.telegram.desktop.desktop"
      rm "$desktop_file"
      install -Dm0644 ${telegramDesktopUnwrapped}/share/applications/org.telegram.desktop.desktop "$desktop_file"
      substituteInPlace "$desktop_file" \
        --replace-fail 'TryExec=Telegram' "TryExec=$out/bin/Telegram" \
        --replace-fail 'Exec=Telegram -- %U' "Exec=$out/bin/Telegram -- %U" \
        --replace-fail 'Exec=Telegram -quit' "Exec=$out/bin/Telegram -quit" \
        --replace-fail 'DBusActivatable=true' 'DBusActivatable=false'
    '';
  };
  zedEditor = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.zed-editor;
  batteryConservationPath = "/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode";
  batteryConservationRootToggle = pkgs.writeShellScriptBin "thinkpad-battery-conservation-root-toggle" ''
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
  batteryConservationToggle = pkgs.writeShellScriptBin "thinkpad-battery-conservation-toggle" ''
    set -euo pipefail

    message=$(/run/wrappers/bin/sudo /run/current-system/sw/bin/thinkpad-battery-conservation-root-toggle)
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
    heliumLauncher
    heliumPackage
    libnotify
    mpv
    nil
    nixd
    orca-slicer
    telegramDesktop
    vial
    zedEditor
    fuzzel
    gtk3
    wlrctl
    swaylock
    swayidle
    grim
    slurp
    wlr-randr
    xwayland-satellite
    adwaita-fonts
  ];

  environment.etc."zed/keymap.json".text = zedKeymap;

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

  system.activationScripts.heliumSingletonCleanup.text = ''
    if ! pgrep -x helium >/dev/null 2>&1; then
      rm -f /home/iva/.config/net.imput.helium/SingletonLock
      rm -f /home/iva/.config/net.imput.helium/SingletonSocket
      rm -f /home/iva/.config/net.imput.helium/SingletonCookie
    fi
  '';

  systemd.tmpfiles.rules = [
    "d /home/iva/.config/zed 0755 iva users - -"
    "L+ /home/iva/.config/zed/keymap.json - - - - /etc/zed/keymap.json"
  ];

  security.sudo.extraRules = [
    {
      users = [ "iva" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/thinkpad-battery-conservation-root-toggle";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ];
    config.common.default = "wlr";
  };

  nixpkgs.overlays = [
    (final: prev: {
      xdg-desktop-portal-wlr = prev.xdg-desktop-portal-wlr.overrideAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [ prev.makeWrapper ];
        postInstall = ''
          ${old.postInstall or ""}
          wrapProgram $out/libexec/xdg-desktop-portal-wlr \
            --prefix PATH : ${prev.lib.makeBinPath [ prev.slurp ]}
        '';
      });
    })
  ];
}
