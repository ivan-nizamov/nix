{ lib, pkgs, ... }:
let
  safeRebuild = pkgs.writeShellScriptBin "mainframe-rebuild" ''
    set -euo pipefail

    git_bin=${lib.getExe pkgs.git}
    nproc_bin=${lib.getExe' pkgs.coreutils "nproc"}
    openclaw_bin=/run/current-system/sw/bin/openclaw
    systemctl=${lib.getExe' pkgs.systemd "systemctl"}
    sudo_bin=/run/wrappers/bin/sudo
    nixos_rebuild=/run/current-system/sw/bin/nixos-rebuild
    self=/run/current-system/sw/bin/mainframe-rebuild
    flake=path:/home/iva/nix#mainframe
    gateway_unit=openclaw-gateway.service
    runtime_dir=/run/mainframe-rebuild

    default_cores() {
      local cpu_count target
      cpu_count=$("$nproc_bin" --all)
      target=$(( cpu_count * 2 / 3 ))
      if [ "$target" -lt 1 ]; then
        target=1
      fi
      printf '%s\n' "$target"
    }

    shell_escape() {
      printf '%q' "$1"
    }

    notify_openclaw=0
    notify_note=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --notify-openclaw)
          notify_openclaw=1
          shift
          ;;
        --notify-note)
          if [ "$#" -lt 2 ]; then
            echo "mainframe-rebuild: --notify-note requires text" >&2
            exit 64
          fi
          notify_note=$2
          shift 2
          ;;
        *)
          break
          ;;
      esac
    done

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
        echo "usage: mainframe-rebuild [--notify-openclaw] [--notify-note TEXT] [build|test|switch] [nixos-rebuild args...]" >&2
        exit 64
        ;;
    esac

    if [ "$mode" = "build" ]; then
      exec "$nixos_rebuild" build --flake "$flake" "$@"
    fi

    if [ "$detached" -eq 0 ]; then
      if [ "$(id -u)" -ne 0 ]; then
        relay_args=()
        if [ "$notify_openclaw" -eq 1 ]; then
          relay_args+=(--notify-openclaw)
        fi
        if [ -n "$notify_note" ]; then
          relay_args+=(--notify-note "$notify_note")
        fi
        relay_args+=("$mode")
        if [ "$#" -gt 0 ]; then
          relay_args+=("$@")
        fi

        exec "$sudo_bin" "$self" "''${relay_args[@]}"
      fi

      if [ "$#" -ne 0 ]; then
        echo "mainframe-rebuild: switch/test use the declarative service defaults and do not accept extra args" >&2
        exit 64
      fi

      mkdir -p "$runtime_dir"
      notify_file="$runtime_dir/notify-$mode.env"
      if [ "$notify_openclaw" -eq 1 ]; then
        {
          printf 'NOTIFY_OPENCLAW=1\n'
          printf 'NOTIFY_NOTE=%s\n' "$(shell_escape "$notify_note")"
        } > "$notify_file"
      else
        rm -f "$notify_file"
      fi

      exec "$systemctl" start "mainframe-rebuild-$mode.service"
    fi

    notify_file="$runtime_dir/notify-$mode.env"
    notify_requested=0
    if [ -f "$notify_file" ]; then
      # shellcheck disable=SC1090
      . "$notify_file"
      if [ "''${NOTIFY_OPENCLAW:-0}" = 1 ]; then
        notify_requested=1
      fi
    fi

    wait_for_gateway() {
      local attempt=0
      while [ "$attempt" -lt 30 ]; do
        if "$openclaw_bin" gateway probe >/dev/null 2>&1; then
          return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
      done
      return 1
    }

    notify_agent() {
      local status=$1
      local state_text
      local diff_stat
      local prompt

      if [ "$notify_requested" -ne 1 ]; then
        return 0
      fi

      rm -f "$notify_file"

      if ! wait_for_gateway; then
        return 0
      fi

      state_text=$("$git_bin" -C /home/iva/nix status --short || true)
      diff_stat=$("$git_bin" -C /home/iva/nix diff --stat || true)

      prompt=$(
        cat <<EOF
A rebuild you previously triggered has finished.

Result: $(if [ "$status" -eq 0 ]; then printf 'success'; else printf 'failure'; fi)
Mode: $mode
Note: ''${NOTIFY_NOTE:-none}

Current git status for /home/iva/nix:
$state_text

Current diff stat for /home/iva/nix:
$diff_stat

Reply to the last active user-facing chat with a concise summary of what changed and whether the rebuild succeeded.
If the rebuild failed, say that clearly and mention the current repo status instead of guessing.
EOF
      )

      "$openclaw_bin" agent \
        --agent main \
        --channel last \
        --deliver \
        --message "$prompt" \
        --timeout 120 >/dev/null 2>&1 || true
    }

    cleanup() {
      status=$?
      if ! "$systemctl" is-active --quiet "$gateway_unit"; then
        echo "mainframe-rebuild: starting $gateway_unit" >&2
        "$systemctl" start "$gateway_unit" || true
      fi
      notify_agent "$status"
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
      RuntimeDirectory = "mainframe-rebuild";
      WorkingDirectory = "/home/iva/nix";
      ExecStart = "${lib.getExe safeRebuild} --run-detached switch";
    };
  };

  systemd.services.mainframe-rebuild-test = {
    description = "Safe NixOS test activation for mainframe";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      RuntimeDirectory = "mainframe-rebuild";
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
