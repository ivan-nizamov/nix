{ config, lib, pkgs, ... }:
let
  cfg = config.local.rebuild;
  openclawNotifications = lib.boolToString cfg.openclawNotifications.enable;
  leaseSeconds = toString cfg.lease.maxSeconds;
  leaseAuthorize = pkgs.writeShellScriptBin "rebuild-authorize" ''
    set -euo pipefail

    self=/run/current-system/sw/bin/rebuild-authorize
    sudo_bin=/run/wrappers/bin/sudo
    lease_dir=/run/rebuild-lease
    lease_file="$lease_dir/lease-until"
    max_seconds=${leaseSeconds}

    parse_duration() {
      local value=''${1:-10m}
      local unit=''${2:-}
      local number suffix seconds

      if [ -n "$unit" ]; then
        number=$value
        case "$unit" in
          s|sec|secs|second|seconds) suffix=s ;;
          m|min|mins|minute|minutes) suffix=m ;;
          h|hr|hrs|hour|hours) suffix=h ;;
          *)
            echo "rebuild-authorize: invalid duration unit: $unit" >&2
            exit 64
            ;;
        esac
      else
        case "$value" in
          *[smh])
            suffix=''${value#''${value%?}}
            number=''${value%?}
            ;;
          *)
            suffix=s
            number=$value
            ;;
        esac
      fi

      case "$number" in
        ""|*[!0-9]*)
          echo "rebuild-authorize: invalid duration: $value" >&2
          exit 64
          ;;
      esac

      if [ -z "$number" ]; then
        echo "rebuild-authorize: invalid duration: $value" >&2
        exit 64
      fi

      case "$suffix" in
        ""|s) seconds=$number ;;
        m) seconds=$((number * 60)) ;;
        h) seconds=$((number * 3600)) ;;
        *)
          echo "rebuild-authorize: invalid duration: $value" >&2
          exit 64
          ;;
      esac

      if [ "$seconds" -lt 1 ]; then
        echo "rebuild-authorize: duration must be positive" >&2
        exit 64
      fi

      if [ "$seconds" -gt "$max_seconds" ]; then
        seconds=$max_seconds
      fi

      printf '%s\n' "$seconds"
    }

    if [ "$(id -u)" -ne 0 ]; then
      exec "$sudo_bin" "$self" "$@"
    fi

    if [ "$#" -gt 2 ]; then
      echo "usage: rebuild-authorize [DURATION]" >&2
      echo "example: rebuild-authorize 10m" >&2
      exit 64
    fi

    seconds=$(parse_duration "''${1:-10m}" "''${2:-}")
    now=$(${pkgs.coreutils}/bin/date +%s)
    expires=$((now + seconds))

    ${pkgs.coreutils}/bin/install -d -o root -g root -m 0755 "$lease_dir"
    printf '%s\n' "$expires" > "$lease_file"
    ${pkgs.coreutils}/bin/chown root:root "$lease_file"
    ${pkgs.coreutils}/bin/chmod 0644 "$lease_file"

    printf 'rebuild lease active for %s seconds, until %s\n' \
      "$seconds" \
      "$(${pkgs.coreutils}/bin/date --date="@$expires" --iso-8601=seconds)"
  '';
  safeRebuild = pkgs.writeShellScriptBin "rebuild" ''
    set -euo pipefail

    git_bin=${lib.getExe pkgs.git}
    date_bin=${lib.getExe' pkgs.coreutils "date"}
    env_bin=${lib.getExe' pkgs.coreutils "env"}
    nproc_bin=${lib.getExe' pkgs.coreutils "nproc"}
    openclaw_bin=/run/current-system/sw/bin/openclaw
    perl_bin=${lib.getExe pkgs.perl}
    rm_bin=${lib.getExe' pkgs.coreutils "rm"}
    runuser_bin=${lib.getExe' pkgs.util-linux "runuser"}
    systemctl=${lib.getExe' pkgs.systemd "systemctl"}
    sudo_bin=/run/wrappers/bin/sudo
    nixos_rebuild=/run/current-system/sw/bin/nixos-rebuild
    self=/run/current-system/sw/bin/rebuild
    flake=path:/home/iva/nix#${cfg.flakeTarget}
    openclaw_notifications=${openclawNotifications}
    gateway_unit=openclaw-gateway.service
    openclaw_home=/home/iva
    runtime_dir=/run/rebuild
    lease_file=/run/rebuild-lease/lease-until

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

    lease_remaining() {
      local now expires

      if [ ! -f "$lease_file" ]; then
        printf '0\n'
        return 0
      fi

      read -r expires < "$lease_file" || {
        printf '0\n'
        return 0
      }

      case "$expires" in
        ""|*[!0-9]*)
          printf '0\n'
          return 0
          ;;
      esac

      now=$("$date_bin" +%s)
      if [ "$expires" -le "$now" ]; then
        printf '0\n'
      else
        printf '%s\n' "$((expires - now))"
      fi
    }

    require_lease() {
      local remaining
      remaining=$(lease_remaining)
      if [ "$remaining" -lt 1 ]; then
        echo "rebuild: no active rebuild lease; run 'rebuild-authorize 10m' first" >&2
        exit 77
      fi
    }

    show_lease_status() {
      local remaining expires
      remaining=$(lease_remaining)
      if [ "$remaining" -lt 1 ]; then
        echo "rebuild lease inactive"
        return 1
      fi
      read -r expires < "$lease_file"
      printf 'rebuild lease active for %s seconds, until %s\n' \
        "$remaining" \
        "$("$date_bin" --date="@$expires" --iso-8601=seconds)"
    }

    notify_openclaw=0
    notify_note=""
    notify_session_id=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --notify-openclaw)
          notify_openclaw=1
          shift
          ;;
        --notify-session-id)
          if [ "$#" -lt 2 ]; then
            echo "rebuild: --notify-session-id requires a value" >&2
            exit 64
          fi
          notify_session_id=$2
          shift 2
          ;;
        --notify-note)
          if [ "$#" -lt 2 ]; then
            echo "rebuild: --notify-note requires text" >&2
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
      build|test|switch|status|revoke)
        shift
        ;;
      *)
        echo "usage: rebuild [--notify-openclaw] [--notify-session-id ID] [--notify-note TEXT] [build|test|switch|status|revoke] [nixos-rebuild args...]" >&2
        exit 64
        ;;
    esac

    if [ "$mode" = "status" ]; then
      show_lease_status
      exit $?
    fi

    if [ "$mode" = "revoke" ]; then
      if [ "$(id -u)" -ne 0 ]; then
        exec "$sudo_bin" "$self" revoke
      fi
      "$rm_bin" -f "$lease_file"
      echo "rebuild lease revoked"
      exit 0
    fi

    if [ "$mode" = "build" ]; then
      exec "$nixos_rebuild" build --flake "$flake" "$@"
    fi

    if [ "$detached" -eq 0 ]; then
      if [ "$(id -u)" -ne 0 ]; then
        relay_args=()
        if [ "$notify_openclaw" -eq 1 ]; then
          relay_args+=(--notify-openclaw)
        fi
        if [ -n "$notify_session_id" ]; then
          relay_args+=(--notify-session-id "$notify_session_id")
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

      require_lease

      if [ "$#" -ne 0 ]; then
        echo "rebuild: switch/test use the declarative service defaults and do not accept extra args" >&2
        exit 64
      fi

      mkdir -p "$runtime_dir"
      notify_file="$runtime_dir/notify-$mode.env"
      if [ "$notify_openclaw" -eq 1 ]; then
        {
          printf 'NOTIFY_OPENCLAW=1\n'
          printf 'NOTIFY_SESSION_ID=%s\n' "$(shell_escape "$notify_session_id")"
          printf 'NOTIFY_NOTE=%s\n' "$(shell_escape "$notify_note")"
        } > "$notify_file"
      else
        rm -f "$notify_file"
      fi

      exec "$systemctl" start "rebuild-$mode.service"
    fi

    require_lease

    notify_file="$runtime_dir/notify-$mode.env"
    notify_requested=0
    if [ -f "$notify_file" ]; then
      # shellcheck disable=SC1090
      . "$notify_file"
      if [ "''${NOTIFY_OPENCLAW:-0}" = 1 ]; then
        notify_requested=1
      fi
    fi

    gateway_ready() {
      exec 3<>/dev/tcp/127.0.0.1/18789
      exec 3>&-
      exec 3<&-
    }

    wait_for_gateway() {
      local attempt=0
      while [ "$attempt" -lt 30 ]; do
        if gateway_ready >/dev/null 2>&1; then
          return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
      done
      return 1
    }

    resolve_delivery_context() {
      local session_id=$1
      local sessions_file="$openclaw_home/.openclaw/agents/main/sessions/sessions.json"

      if [ -z "$session_id" ] || [ ! -f "$sessions_file" ]; then
        return 1
      fi

      "$perl_bin" -MJSON::PP -e '
        use strict;
        use warnings;

        my ($path, $target) = @ARGV;
        my $data = eval {
          local $/;
          open my $fh, "<", $path or die $!;
          JSON::PP->new->decode(<$fh>);
        };
        exit 1 if !$data || ref($data) ne "HASH";

        my ($session) = grep {
          ref($_) eq "HASH" && (($_->{sessionId} // q{}) eq $target)
        } values %{$data};
        exit 1 if !$session;

        my $ctx = $session->{deliveryContext} // {};
        for my $field (qw(channel to accountId threadId)) {
          my $value = $ctx->{$field};
          next if !defined($value) || $value eq q{};
          print uc($field), q{=}, $value, "\n";
        }
      ' "$sessions_file" "$session_id"
    }

    notify_agent() {
      local status=$1
      local delivery_context
      local delivery_channel=""
      local delivery_to=""
      local delivery_target=""
      local delivery_thread_id=""
      local delivery_account=""
      local state_text
      local diff_stat
      local prompt
      local agent_reply=""

      if [ "$notify_requested" -ne 1 ]; then
        return 0
      fi

      rm -f "$notify_file"

      if ! wait_for_gateway; then
        return 0
      fi

      state_text=$("$git_bin" -C /home/iva/nix status --short || true)
      diff_stat=$("$git_bin" -C /home/iva/nix diff --stat || true)
      if [ -n "''${NOTIFY_SESSION_ID:-}" ]; then
        delivery_context=$(resolve_delivery_context "$NOTIFY_SESSION_ID" || true)
        if [ -n "$delivery_context" ]; then
          while IFS='=' read -r key value; do
            case "$key" in
              CHANNEL) delivery_channel=$value ;;
              TO) delivery_to=$value ;;
              THREADID) delivery_thread_id=$value ;;
              ACCOUNTID) delivery_account=$value ;;
            esac
          done <<EOF
$delivery_context
EOF
        fi
      fi

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

Write a concise human-facing update about what changed and whether the rebuild succeeded.
If the rebuild failed, say that clearly and mention the current repo status instead of guessing.
EOF
      )

      if [ -n "''${NOTIFY_SESSION_ID:-}" ]; then
        notify_args=(
          agent
          --agent main
          --session-id "$NOTIFY_SESSION_ID"
          --message "$prompt"
          --timeout 120
        )
        if [ -n "$delivery_channel" ]; then
          notify_args+=(--channel "$delivery_channel")
        fi

        agent_reply=$("$runuser_bin" -u iva -- "$env_bin" HOME="$openclaw_home" OPENCLAW_STATE_DIR="$openclaw_home/.openclaw" "$openclaw_bin" "''${notify_args[@]}" 2>/dev/null || true)

        if [ -n "$agent_reply" ] && [ -n "$delivery_channel" ] && [ -n "$delivery_to" ]; then
          delivery_target=$delivery_to
          if [ "$delivery_channel" = "telegram" ]; then
            delivery_target="''${delivery_target#telegram:}"
            delivery_target="''${delivery_target%%:topic:*}"
          fi

          message_args=(
            message
            send
            --channel "$delivery_channel"
            --target "$delivery_target"
            --message "$agent_reply"
          )
          if [ -n "$delivery_account" ]; then
            message_args+=(--account "$delivery_account")
          fi
          if [ -n "$delivery_thread_id" ] && [ "$delivery_channel" = "telegram" ]; then
            message_args+=(--thread-id "$delivery_thread_id")
          fi

          "$runuser_bin" -u iva -- "$env_bin" HOME="$openclaw_home" OPENCLAW_STATE_DIR="$openclaw_home/.openclaw" "$openclaw_bin" "''${message_args[@]}" >/dev/null 2>&1 || true
        elif [ -n "$agent_reply" ]; then
          printf '%s\n' "$agent_reply" >&2
        fi
      else
        "$runuser_bin" -u iva -- "$env_bin" HOME="$openclaw_home" OPENCLAW_STATE_DIR="$openclaw_home/.openclaw" "$openclaw_bin" agent \
          --agent main \
          --channel last \
          --deliver \
          --message "$prompt" \
          --timeout 120 >/dev/null 2>&1 || true
      fi
    }

    cleanup() {
      status=$?
      if [ "$openclaw_notifications" = true ]; then
        if ! "$systemctl" is-active --quiet "$gateway_unit"; then
          echo "rebuild: starting $gateway_unit" >&2
          "$systemctl" start "$gateway_unit" || true
        fi
        notify_agent "$status"
      fi
      exit "$status"
    }

    trap cleanup EXIT

    if [ "$#" -eq 0 ]; then
      set -- --max-jobs 1 --cores "$(default_cores)"
    fi

    "$nixos_rebuild" "$mode" --flake "$flake" "$@"
  '';
  legacyRebuild = pkgs.writeShellScriptBin "mainframe-rebuild" ''
    exec /run/current-system/sw/bin/rebuild "$@"
  '';
  legacyRebuildAuthorize = pkgs.writeShellScriptBin "mainframe-rebuild-authorize" ''
    exec /run/current-system/sw/bin/rebuild-authorize "$@"
  '';
in
{
  options.local.rebuild.flakeTarget = lib.mkOption {
    type = lib.types.str;
    default = "legion";
    description = "Flake target used by local rebuild helpers.";
  };

  options.local.rebuild.openclawNotifications.enable = lib.mkEnableOption "OpenClaw rebuild notifications";

  options.local.rebuild.lease.maxSeconds = lib.mkOption {
    type = lib.types.ints.positive;
    default = 1800;
    description = "Maximum rebuild lease duration, in seconds.";
  };

  config = {
    environment.systemPackages = [
      leaseAuthorize
      legacyRebuild
      legacyRebuildAuthorize
      safeRebuild
    ];

    systemd.services.rebuild-switch = {
      description = "Safe NixOS switch";
      restartIfChanged = false;
      stopIfChanged = false;
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        RuntimeDirectory = "rebuild";
        WorkingDirectory = "/home/iva/nix";
        ExecStart = "${lib.getExe safeRebuild} --run-detached switch";
      };
    };

    systemd.services.rebuild-test = {
      description = "Safe NixOS test activation";
      restartIfChanged = false;
      stopIfChanged = false;
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        RuntimeDirectory = "rebuild";
        WorkingDirectory = "/home/iva/nix";
        ExecStart = "${lib.getExe safeRebuild} --run-detached test";
      };
    };

    security.sudo.extraRules = [
      {
        users = [ "iva" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/rebuild";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
