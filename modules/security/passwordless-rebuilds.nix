{ lib, pkgs, ... }:
let
  safeRebuild = pkgs.writeShellScriptBin "mainframe-rebuild" ''
    set -euo pipefail

    systemctl=${lib.getExe' pkgs.systemd "systemctl"}
    sudo_bin=/run/wrappers/bin/sudo
    nixos_rebuild=/run/current-system/sw/bin/nixos-rebuild
    self=/run/current-system/sw/bin/mainframe-rebuild
    flake=path:/home/iva/nix#mainframe
    gateway_unit=openclaw-gateway.service

    default_cores() {
      local cpu_count target
      cpu_count=$(${lib.getExe' pkgs.coreutils "nproc"} --all)
      target=$(( cpu_count * 2 / 3 ))
      if [ "$target" -lt 1 ]; then
        target=1
      fi
      printf '%s\n' "$target"
    }

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

      if [ "$#" -ne 0 ]; then
        echo "mainframe-rebuild: switch/test use the declarative service defaults and do not accept extra args" >&2
        exit 64
      fi

      exec "$systemctl" start "mainframe-rebuild-$mode.service"
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

    if [ "$#" -eq 0 ]; then
      set -- --max-jobs 1 --cores "$(default_cores)"
    fi

    "$nixos_rebuild" "$mode" --flake "$flake" "$@"
  '';
in
{
  environment.systemPackages = [ safeRebuild ];

  systemd.services.mainframe-rebuild-switch = {
    description = "Safe NixOS switch for mainframe";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      WorkingDirectory = "/home/iva/nix";
      ExecStart = "${lib.getExe safeRebuild} --run-detached switch";
    };
  };

  systemd.services.mainframe-rebuild-test = {
    description = "Safe NixOS test activation for mainframe";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      WorkingDirectory = "/home/iva/nix";
      ExecStart = "${lib.getExe safeRebuild} --run-detached test";
    };
  };

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
