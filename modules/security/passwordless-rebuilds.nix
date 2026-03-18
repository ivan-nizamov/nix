{ lib, pkgs, ... }:
let
  safeRebuild = pkgs.writeShellScriptBin "mainframe-rebuild" ''
    set -euo pipefail

    systemd_run=${lib.getExe' pkgs.systemd "systemd-run"}
    systemctl=${lib.getExe' pkgs.systemd "systemctl"}
    sudo_bin=/run/wrappers/bin/sudo
    nixos_rebuild=/run/current-system/sw/bin/nixos-rebuild
    self=/run/current-system/sw/bin/mainframe-rebuild
    flake=path:/home/iva/nix#mainframe
    gateway_unit=openclaw-gateway.service

    detached=0
    if [ "''${1:-}" = "--run-detached" ]; then
      detached=1
      shift
    fi

    mode=''${1:-switch}
    case "$mode" in
      build|test|switch)
        shift
        ;;
      *)
        echo "usage: mainframe-rebuild [build|test|switch] [nixos-rebuild args...]" >&2
        exit 64
        ;;
    esac

    if [ "$mode" = "build" ]; then
      exec "$nixos_rebuild" build --flake "$flake" "$@"
    fi

    if [ "$detached" -eq 0 ]; then
      if [ "$(id -u)" -ne 0 ]; then
        exec "$sudo_bin" "$self" "$mode" "$@"
      fi

      unit="mainframe-rebuild-$mode-$(date +%Y%m%d%H%M%S)"
      exec "$systemd_run" \
        --collect \
        --pipe \
        --quiet \
        --same-dir \
        --service-type=exec \
        --unit "$unit" \
        --wait \
        "$self" --run-detached "$mode" "$@"
    fi

    cleanup() {
      status=$?
      if ! "$systemctl" is-active --quiet "$gateway_unit"; then
        echo "mainframe-rebuild: starting $gateway_unit" >&2
        "$systemctl" start "$gateway_unit" || true
      fi
      exit "$status"
    }

    trap cleanup EXIT

    "$nixos_rebuild" "$mode" --flake "$flake" "$@"
  '';
in
{
  environment.systemPackages = [ safeRebuild ];

  security.sudo.extraRules = [
    {
      users = [ "iva" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/mainframe-rebuild";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
